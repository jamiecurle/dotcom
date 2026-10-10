defmodule Jamie.MailingList do
  @moduledoc """
  The mailing list: people subscribe by email to one or more "worlds" (or
  everything) and get a digest daily, weekly or monthly.

  The whole thing is behind a hardcoded switch in config.exs until it's
  finished and the privacy notice says what it does:

      config :jamie, :mailing_list, enabled: false

  While it's off, only I (signed in) can see any of it.
  """

  alias Jamie.Accounts.Scope
  alias Jamie.MailingList.{Notifier, Subscriber, Suppression}
  alias Jamie.Repo
  alias Plug.Crypto.KeyGenerator

  import Ecto.Query, only: [from: 2]

  # The worlds, in the order the form offers them. Each is also the tag that
  # puts a post into it. "everything" is all of them, and anything to come.
  @worlds ~w(treeworld techworld makerworld privacyworld foodworld miscworld)

  @doc """
  True when the mailing list is switched on for everyone.
  """
  def enabled?, do: Application.get_env(:jamie, :mailing_list, [])[:enabled] == true

  @doc """
  Whether the mailing list should be shown to whoever this is: everyone when
  it's switched on, otherwise only me.
  """
  def visible?(%Scope{user: user}) when not is_nil(user), do: true
  def visible?(_scope), do: enabled?()

  @doc "The worlds that can be subscribed to, as tag slugs."
  def worlds, do: @worlds

  @doc "How often a digest can be sent."
  defdelegate frequencies, to: Subscriber

  ## Subscribers

  @doc """
  The subscriber behind a manage link, or nil. Anything that isn't a
  well-formed uuid is simply not found, rather than an error.
  """
  def get_subscriber(id) do
    case Ecto.UUID.cast(id) do
      {:ok, uuid} -> Repo.get(Subscriber, uuid)
      :error -> nil
    end
  end

  ## Signing up

  # how long a confirmation link lasts, and how soon the same address can
  # be emailed again by signing up twice
  @confirm_for_days 7
  @resend_after_minutes 15

  @doc """
  Handles the sign-up form. It answers `:ok` whether the address was new,
  already subscribed or suppressed, so the form can't be used to find out
  who's on the list; the difference only shows in what gets emailed:

    * a new address is saved as pending and sent a confirmation link
    * a pending one has its choices updated and the link sent again
    * a confirmed one is sent its manage link instead
    * a suppressed one is sent nothing

  Repeat sign-ups within #{@resend_after_minutes} minutes don't send again.
  Invalid input comes back as `{:error, changeset}`.
  """
  def subscribe(attrs, url_fun) do
    changeset = Subscriber.signup_changeset(%Subscriber{}, attrs)

    with {:ok, signup} <- Ecto.Changeset.apply_action(changeset, :insert) do
      cond do
        suppressed?(signup.email) ->
          :ok

        existing = Repo.get_by(Subscriber, email: signup.email) ->
          resubscribe(existing, attrs, url_fun)

        true ->
          start(changeset, url_fun)
      end
    end
  end

  defp start(changeset, url_fun) do
    {token, hash} = confirm_token()

    changeset
    |> Ecto.Changeset.put_change(:confirm_token_hash, hash)
    |> Ecto.Changeset.put_change(:confirm_sent_at, DateTime.utc_now())
    |> Repo.insert()
    |> case do
      {:ok, subscriber} ->
        Notifier.deliver_confirmation(subscriber, url_fun.({:confirm, token}))
        :ok

      # lost a race with the same address signing up at the same moment
      {:error, _changeset} ->
        :ok
    end
  end

  defp resubscribe(subscriber, attrs, url_fun) do
    cond do
      recently_mailed?(subscriber) ->
        :ok

      subscriber.status == :pending ->
        {token, hash} = confirm_token()

        {:ok, subscriber} =
          subscriber
          |> Subscriber.preferences_changeset(attrs)
          |> Ecto.Changeset.put_change(:confirm_token_hash, hash)
          |> Ecto.Changeset.put_change(:confirm_sent_at, DateTime.utc_now())
          |> Repo.update()

        Notifier.deliver_confirmation(subscriber, url_fun.({:confirm, token}))
        :ok

      true ->
        {:ok, subscriber} =
          subscriber
          |> Ecto.Changeset.change(confirm_sent_at: DateTime.utc_now())
          |> Repo.update()

        Notifier.deliver_already_subscribed(subscriber, url_fun.({:manage, subscriber.id}))
        :ok
    end
  end

  defp recently_mailed?(%Subscriber{confirm_sent_at: nil}), do: false

  defp recently_mailed?(%Subscriber{confirm_sent_at: sent_at}) do
    DateTime.diff(DateTime.utc_now(), sent_at, :minute) < @resend_after_minutes
  end

  # The token goes in the email; only its hash is stored, so the database
  # alone can't confirm anyone.
  defp confirm_token do
    token = :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
    {token, hash_token(token)}
  end

  defp hash_token(token), do: :crypto.hash(:sha256, token)

  @doc """
  The pending subscriber a confirmation link belongs to, or nil when the
  link is wrong, used or more than #{@confirm_for_days} days old.
  """
  def get_pending_by_token(token) when is_binary(token) do
    cutoff = DateTime.add(DateTime.utc_now(), -@confirm_for_days, :day)

    Repo.one(
      from s in Subscriber,
        where:
          s.confirm_token_hash == ^hash_token(token) and s.status == :pending and
            s.confirm_sent_at > ^cutoff
    )
  end

  @doc """
  Confirms a subscription: the second half of double opt-in. Records which
  privacy notice they agreed to and spends the token.
  """
  def confirm(%Subscriber{status: :pending} = subscriber) do
    subscriber
    |> Ecto.Changeset.change(
      status: :confirmed,
      confirmed_at: DateTime.utc_now(),
      consent_notice_version: Application.get_env(:jamie, :mailing_list)[:privacy_notice_version],
      confirm_token_hash: nil
    )
    |> Repo.update()
  end

  @doc """
  Deletes sign-ups that were never confirmed, once their link has expired.
  Returns how many went.
  """
  def purge_unconfirmed do
    cutoff = DateTime.add(DateTime.utc_now(), -@confirm_for_days, :day)

    {count, _} =
      Repo.delete_all(
        from s in Subscriber, where: s.status == :pending and s.inserted_at < ^cutoff
      )

    count
  end

  ## Suppressions

  @doc """
  Records that `email` must never be mailed again. Only a keyed hash of the
  address is stored. Suppressing an address twice is fine.
  """
  def suppress(email, reason) do
    Repo.insert(
      %Suppression{email_hash: email_hash(email), reason: reason},
      on_conflict: :nothing,
      conflict_target: :email_hash
    )
  end

  @doc "True when `email` is on the suppression list."
  def suppressed?(email) do
    Repo.exists?(from s in Suppression, where: s.email_hash == ^email_hash(email))
  end

  # An HMAC of the normalised address, keyed from the app's secret so the
  # list can't be checked against a list of addresses by anyone holding only
  # the database. (Rotating secret_key_base would orphan existing entries.)
  defp email_hash(email) do
    key =
      KeyGenerator.generate(
        JamieWeb.Endpoint.config(:secret_key_base),
        "mailing list suppressions"
      )

    :crypto.mac(:hmac, :sha256, key, email |> String.trim() |> String.downcase())
  end
end
