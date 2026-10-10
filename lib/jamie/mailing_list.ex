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
  alias Jamie.MailingList.{Subscriber, Suppression}
  alias Jamie.Repo
  alias Plug.Crypto.KeyGenerator

  import Ecto.Query, only: [from: 2]

  # The worlds, in the order the form offers them. Each is also the tag that
  # puts a post into it. "everything" is all of them, and anything to come.
  @worlds ~w(treeworld techworld makerworld privacyworld foodworld miscworld)
  @frequencies [:daily, :weekly, :monthly]

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
  def frequencies, do: @frequencies

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
