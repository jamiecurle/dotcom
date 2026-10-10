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
end
