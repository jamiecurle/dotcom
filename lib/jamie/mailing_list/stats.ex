defmodule Jamie.MailingList.Stats do
  @moduledoc """
  The numbers behind the deliverability dashboard: who's subscribed, and
  how mail to them is faring according to Postmark's webhooks.

  Rates are judged against what mailbox providers act on. Gmail and Yahoo
  want spam complaints kept under 0.1% and treat 0.3% as a hard line;
  bounces much over a few percent mean a list isn't being kept clean.
  """

  import Ecto.Query, only: [from: 2]

  alias Jamie.MailingList
  alias Jamie.MailingList.{EmailEvent, Subscriber, Suppression}
  alias Jamie.Repo

  @permanent ["HardBounce", "BadEmailAddress"]
  @temporary ["SoftBounce", "Transient", "DnsError"]

  # {warn at, bad at}, as fractions
  @bounce_limits {0.02, 0.05}
  @complaint_limits {0.001, 0.003}

  @doc """
  Subscriber counts by status, and of the confirmed ones by frequency and
  by world ("everything" counted on its own).
  """
  def subscribers do
    by_status = count_by(from(s in Subscriber, group_by: s.status, select: {s.status, count()}))

    confirmed = from(s in Subscriber, where: s.status == :confirmed)

    by_frequency =
      count_by(from(s in confirmed, group_by: s.frequency, select: {s.frequency, count()}))

    everything = Repo.aggregate(from(s in confirmed, where: s.everything), :count)

    by_world =
      Map.new(MailingList.worlds(), fn world ->
        {world, Repo.aggregate(from(s in confirmed, where: ^world in s.worlds), :count)}
      end)

    %{
      by_status: by_status,
      by_frequency: by_frequency,
      by_world: Map.put(by_world, "everything", everything),
      suppressed: Repo.aggregate(Suppression, :count)
    }
  end

  @doc """
  What happened to mail over the last `days`: deliveries, bounces split by
  kind, spam complaints, and the bounce and complaint rates with a verdict
  (`:ok`, `:warn` or `:bad`) for each.
  """
  def summary(days) do
    counts =
      from(e in EmailEvent,
        where: e.occurred_at > ago(^days, "day"),
        group_by: [e.record_type, e.type],
        select: {e.record_type, e.type, count()}
      )
      |> Repo.all()
      |> Enum.reduce(empty_counts(), fn {record_type, type, n}, acc ->
        Map.update!(acc, kind(record_type, type), &(&1 + n))
      end)

    bounced = counts.hard_bounces + counts.soft_bounces
    attempted = counts.delivered + bounced

    bounce_rate = rate(bounced, attempted)
    complaint_rate = rate(counts.complaints, counts.delivered)

    Map.merge(counts, %{
      bounce_rate: bounce_rate,
      bounce_health: health(bounce_rate, @bounce_limits),
      complaint_rate: complaint_rate,
      complaint_health: health(complaint_rate, @complaint_limits)
    })
  end

  @doc """
  The same counts day by day, oldest first, for the last `days`. Days with
  nothing are included, so the list is always `days` long.
  """
  def daily(days) do
    today = Date.utc_today()

    rows =
      from(e in EmailEvent,
        where: e.occurred_at > ago(^days, "day"),
        group_by: [fragment("?::date", e.occurred_at), e.record_type, e.type],
        select: {fragment("?::date", e.occurred_at), e.record_type, e.type, count()}
      )
      |> Repo.all()
      |> Enum.group_by(&elem(&1, 0))

    for offset <- (days - 1)..0//-1 do
      date = Date.add(today, -offset)

      counts =
        rows
        |> Map.get(date, [])
        |> Enum.reduce(empty_counts(), fn {_date, record_type, type, n}, acc ->
          Map.update!(acc, kind(record_type, type), &(&1 + n))
        end)

      Map.put(counts, :date, date)
    end
  end

  @doc "The most recent events, newest first, with their subscriber if still subscribed."
  def recent_events(limit) do
    Repo.all(
      from e in EmailEvent,
        order_by: [desc: e.occurred_at, desc: e.id],
        limit: ^limit,
        preload: :subscriber
    )
  end

  @doc "Everyone on the list, newest first."
  def list_subscribers(limit) do
    Repo.all(from s in Subscriber, order_by: [desc: s.inserted_at], limit: ^limit)
  end

  @doc """
  Everything Postmark has said about one subscriber's address, newest
  first. Matched on the address hash, so it includes events from before
  they last signed up.
  """
  def subscriber_events(%Subscriber{email: email}) do
    hash = MailingList.email_hash(email)
    Repo.all(from e in EmailEvent, where: e.email_hash == ^hash, order_by: [desc: e.occurred_at])
  end

  @doc "Which group an event falls in on the dashboard."
  def kind("Delivery", _type), do: :delivered
  def kind("SpamComplaint", _type), do: :complaints
  def kind("Bounce", type) when type in @permanent, do: :hard_bounces
  def kind("Bounce", type) when type in @temporary, do: :soft_bounces
  def kind("SubscriptionChange", _type), do: :suppression_changes
  def kind(_record_type, _type), do: :other

  defp empty_counts do
    %{
      delivered: 0,
      hard_bounces: 0,
      soft_bounces: 0,
      complaints: 0,
      suppression_changes: 0,
      other: 0
    }
  end

  defp count_by(query), do: query |> Repo.all() |> Map.new()

  defp rate(_part, 0), do: nil
  defp rate(part, whole), do: part / whole

  defp health(nil, _limits), do: :ok
  defp health(rate, {_warn, bad}) when rate >= bad, do: :bad
  defp health(rate, {warn, _bad}) when rate >= warn, do: :warn
  defp health(_rate, _limits), do: :ok
end
