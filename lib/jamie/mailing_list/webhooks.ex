defmodule Jamie.MailingList.Webhooks do
  @moduledoc """
  Acts on Postmark's webhooks, keeping a record of every one.

  What each kind of event does to the subscriber it's about:

    * **hard bounce**, bad address or **spam complaint**: the address goes
      on the suppression list and the subscriber is deleted. Never mail it
      again.
    * **soft bounce** (or a transient or DNS failure): counted. Three in a
      row and the subscriber is suspended.
    * **delivery**: the soft bounce count goes back to zero.
    * Postmark's **unsubscribe** bounce type (someone replied asking to be
      removed), or Postmark **suppressing** the address itself (say through
      its own unsubscribe link): the subscriber is deleted. Postmark's
      hard bounce and spam reasons also suppress the address here.
    * anything else is only recorded.

  Postmark retries until it gets a 2xx, so each event has a dedupe key and
  is acted on once. The event and its consequences share a transaction:
  if anything fails, nothing is kept, and the retry tries again.
  """

  import Ecto.Query, only: [from: 2]

  alias Jamie.MailingList
  alias Jamie.MailingList.{EmailEvent, Subscriber}
  alias Jamie.Repo

  @soft_bounce_limit 3

  # bounce types (Postmark's TypeCode) by what they mean for the address
  @permanent ["HardBounce", "BadEmailAddress"]
  @temporary ["SoftBounce", "Transient", "DnsError"]

  @doc """
  Handles one webhook payload. Returns `{:ok, event}`, `{:ok, :duplicate}`
  for a retry of one already handled, or `{:error, reason}`.
  """
  def handle(%{"RecordType" => record_type} = payload) do
    email = payload["Email"] || payload["Recipient"]
    subscriber = email && Repo.get_by(Subscriber, email: email)

    Repo.transaction(fn ->
      case insert_event(payload, record_type, email, subscriber) do
        {:ok, %EmailEvent{id: nil}} ->
          :duplicate

        {:ok, event} ->
          action = act(record_type, payload, email, subscriber)
          event |> Ecto.Changeset.change(action: action) |> Repo.update!()

        {:error, changeset} ->
          Repo.rollback(changeset)
      end
    end)
  end

  def handle(_payload), do: {:error, :unrecognised}

  defp insert_event(payload, record_type, email, subscriber) do
    Repo.insert(
      %EmailEvent{
        record_type: record_type,
        type: payload["Type"] || payload["SuppressionReason"],
        type_code: payload["TypeCode"],
        message_id: payload["MessageID"],
        message_stream: payload["MessageStream"],
        email_hash: email && MailingList.email_hash(email),
        subscriber_id: subscriber && subscriber.id,
        occurred_at: occurred_at(payload),
        payload: scrub(payload, email),
        dedupe_key: dedupe_key(record_type, payload)
      },
      on_conflict: :nothing,
      conflict_target: :dedupe_key
    )
  end

  ## What each event does. Returns a word for the record of what was done.

  defp act("Bounce", %{"Type" => type}, email, subscriber) when type in @permanent,
    do: suppress_and_delete(email, subscriber, :hard_bounce)

  defp act("Bounce", %{"Type" => type}, _email, subscriber) when type in @temporary,
    do: soft_bounce(subscriber)

  defp act("Bounce", %{"Type" => "Unsubscribe"}, _email, subscriber), do: delete(subscriber)

  defp act("SpamComplaint", _payload, email, subscriber),
    do: suppress_and_delete(email, subscriber, :spam_complaint)

  defp act("Delivery", _payload, _email, %Subscriber{soft_bounce_count: count} = subscriber)
       when count > 0 do
    subscriber |> Ecto.Changeset.change(soft_bounce_count: 0) |> Repo.update!()
    "reset_soft_bounces"
  end

  defp act("SubscriptionChange", %{"SuppressSending" => true} = payload, email, subscriber) do
    case payload["SuppressionReason"] do
      "HardBounce" -> suppress_and_delete(email, subscriber, :hard_bounce)
      "SpamComplaint" -> suppress_and_delete(email, subscriber, :spam_complaint)
      _manual -> delete(subscriber)
    end
  end

  defp act(_record_type, _payload, _email, _subscriber), do: "recorded"

  defp suppress_and_delete(nil, _subscriber, _reason), do: "recorded"

  defp suppress_and_delete(email, subscriber, reason) do
    {:ok, _} = MailingList.suppress(email, reason)
    delete(subscriber)
    "suppressed"
  end

  defp delete(nil), do: "recorded"

  # the event keeps its own copy of the hash, so the history survives
  defp delete(subscriber) do
    Repo.delete_all(from s in Subscriber, where: s.id == ^subscriber.id)
    "deleted"
  end

  defp soft_bounce(nil), do: "recorded"

  defp soft_bounce(subscriber) do
    {1, [%{soft_bounce_count: count}]} =
      Repo.update_all(
        from(s in Subscriber, where: s.id == ^subscriber.id, select: s),
        inc: [soft_bounce_count: 1]
      )

    if count >= @soft_bounce_limit do
      Repo.update_all(from(s in Subscriber, where: s.id == ^subscriber.id),
        set: [status: :suspended]
      )

      "suspended"
    else
      "counted_soft_bounce"
    end
  end

  ## The record

  # Retries repeat the payload exactly, so the key only needs to tell
  # distinct events apart. Bounces and complaints carry their own id.
  defp dedupe_key(type, %{"ID" => id}) when type in ["Bounce", "SpamComplaint"],
    do: "#{type}:#{id}"

  defp dedupe_key(type, payload) do
    parts = [payload["MessageID"], payload["Recipient"], payload["DeliveredAt"]]
    parts = parts ++ [payload["ChangedAt"], payload["SuppressSending"]]

    digest =
      :crypto.hash(:sha256, :erlang.term_to_binary(parts)) |> Base.encode16(case: :lower)

    "#{type}:#{digest}"
  end

  defp occurred_at(payload) do
    stamp = payload["BouncedAt"] || payload["DeliveredAt"] || payload["ChangedAt"]

    case stamp && DateTime.from_iso8601(stamp) do
      # Postmark usually sends 7 fractional digits, but not always any;
      # the column wants exactly microseconds either way
      {:ok, %DateTime{microsecond: {us, _}} = datetime, _offset} ->
        %{datetime | microsecond: {us, 6}}

      _ ->
        DateTime.utc_now()
    end
  end

  # Out go the address and the full message dump; the address is also
  # blanked anywhere else it turns up, like the remote server's reply.
  @dropped ~w(Email Recipient Content From Metadata)

  defp scrub(payload, email) do
    payload
    |> Map.drop(@dropped)
    |> Map.new(fn {key, value} -> {key, redact(value, email)} end)
  end

  defp redact(value, email) when is_binary(value) and is_binary(email),
    do: Regex.replace(~r/#{Regex.escape(email)}/i, value, "[recipient]")

  defp redact(value, _email), do: value
end
