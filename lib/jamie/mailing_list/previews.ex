defmodule Jamie.MailingList.Previews do
  @moduledoc """
  The mailing list's emails filled with something real enough to judge
  them by: the latest published posts, and a made-up subscriber. Used by
  the office's preview page and the raw `/office/mailing-list/emails/...`
  urls, so what's previewed is built exactly as what's sent.
  """

  import Ecto.Query, only: [from: 2]

  alias Jamie.Content.Post
  alias Jamie.MailingList.Notifier
  alias Jamie.Repo

  @emails ~w(digest confirmation already-subscribed)
  @frequencies ~w(daily weekly monthly)

  @doc "The emails there are to preview, as they appear in urls."
  def emails, do: @emails

  @doc "The digest frequencies, as they appear in urls."
  def frequencies, do: @frequencies

  @doc """
  The named email as a `%Swoosh.Email{}`, or `nil` for a name that isn't
  one. Names and frequencies come from urls, so they're matched against
  the lists above rather than turned into atoms.
  """
  def email(name, frequency \\ "weekly", url_fun)

  def email("digest", frequency, url_fun) when frequency in @frequencies do
    Notifier.digest_email(
      subscriber(),
      latest_posts(),
      frequency(frequency),
      url_fun
    )
  end

  def email("confirmation", _frequency, url_fun) do
    Notifier.confirmation_email(subscriber(), url_fun.({:confirm, "preview-token"}))
  end

  def email("already-subscribed", _frequency, url_fun) do
    Notifier.already_subscribed_email(subscriber(), url_fun.({:manage, subscriber().id}))
  end

  def email(_name, _frequency, _url_fun), do: nil

  @doc "A frequency from a url as the atom the Notifier takes."
  def frequency("daily"), do: :daily
  def frequency("weekly"), do: :weekly
  def frequency("monthly"), do: :monthly

  @doc "The posts a sample digest holds: the three most recently published."
  def latest_posts(limit \\ 3) do
    Repo.all(
      from p in Post,
        where: p.status == :published,
        order_by: [desc: p.published_on, desc: p.id],
        limit: ^limit
    )
  end

  # nobody real: its manage link leads to the not-found page
  defp subscriber, do: %{id: "00000000-0000-0000-0000-000000000000", email: "reader@example.com"}
end
