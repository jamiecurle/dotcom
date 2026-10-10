defmodule Jamie.MailingList.Digests do
  @moduledoc """
  Building and sending the digests: an email per subscriber with the posts
  published in their worlds since they last heard from us.

  Timing lives in config.exs (Oban cron, London time): daily at 8am,
  Fridays at 8am, the 28th at 8am. Each run is a *period*, named after the
  frequency and London date, e.g. "weekly:2026-10-16". A subscriber gets at
  most one digest per period, however often a job runs.

  Which posts: published ones tagged with any of their worlds (or any post
  at all for "everything"), published since they confirmed, and not in a
  digest they've already had. An empty digest isn't sent.
  """

  import Ecto.Query, only: [from: 2]

  alias Jamie.Content.Post
  alias Jamie.MailingList.{DigestSend, Notifier, Subscriber}
  alias Jamie.Repo

  @zone "Europe/London"

  @doc "Today's date in London, which is the date the periods go by."
  def today, do: @zone |> DateTime.now!() |> DateTime.to_date()

  @doc "The name of the period a digest belongs to."
  def period(frequency, %Date{} = date), do: "#{frequency}:#{Date.to_iso8601(date)}"

  @doc "The ids of confirmed subscribers who take this frequency."
  def due(frequency) do
    Repo.all(
      from s in Subscriber,
        where: s.status == :confirmed and s.frequency == ^frequency,
        select: s.id
    )
  end

  @doc """
  The posts a subscriber's next digest would hold, oldest first.
  """
  def posts_for(%Subscriber{} = subscriber) do
    since = subscriber.confirmed_at |> DateTime.shift_zone!(@zone) |> DateTime.to_date()

    already_sent =
      from d in DigestSend,
        where: d.subscriber_id == ^subscriber.id,
        select: fragment("unnest(?)", d.post_ids)

    query =
      from p in Post,
        where: p.status == :published and p.published_on >= ^since,
        where: p.id not in subquery(already_sent),
        order_by: [asc: p.published_on, asc: p.id]

    query |> in_worlds(subscriber) |> Repo.all()
  end

  defp in_worlds(query, %Subscriber{everything: true}), do: query

  defp in_worlds(query, %Subscriber{worlds: worlds}) do
    tagged =
      from tp in "tags_posts",
        join: t in "tags",
        on: t.id == tp.tag_id,
        where: t.slug in ^worlds,
        select: tp.post_id

    from p in query, where: p.id in subquery(tagged)
  end

  @doc """
  Sends one subscriber their digest for `period`. Returns:

    * `{:ok, %DigestSend{}}` when it went
    * `{:ok, :already_sent}` when this period's digest already went
    * `{:ok, :nothing_new}` when there was nothing to put in it
    * `{:ok, :not_subscribed}` when they've gone, or aren't confirmed
    * `{:error, reason}` when Postmark wouldn't take it, to retry

  The send is recorded *before* the email goes, so a crash between the two
  can never mean a second email; if delivery fails the record is removed
  so a retry can try again.
  """
  def deliver(subscriber_id, period, frequency, url_fun) do
    with %Subscriber{status: :confirmed} = subscriber <- Repo.get(Subscriber, subscriber_id),
         false <- sent?(subscriber, period),
         [_ | _] = posts <- posts_for(subscriber),
         {:ok, %DigestSend{id: id} = send} when not is_nil(id) <-
           reserve(subscriber, period, frequency, posts) do
      case Notifier.deliver_digest(subscriber, posts, frequency, url_fun) do
        {:ok, message_id} ->
          now = DateTime.utc_now()
          subscriber |> Ecto.Changeset.change(last_sent_at: now) |> Repo.update!()
          {:ok, send |> Ecto.Changeset.change(message_id: message_id) |> Repo.update!()}

        {:error, reason} ->
          Repo.delete!(send)
          {:error, reason}
      end
    else
      nil -> {:ok, :not_subscribed}
      true -> {:ok, :already_sent}
      %Subscriber{} -> {:ok, :not_subscribed}
      [] -> {:ok, :nothing_new}
      {:ok, %DigestSend{id: nil}} -> {:ok, :already_sent}
    end
  end

  defp sent?(subscriber, period) do
    Repo.exists?(
      from d in DigestSend, where: d.subscriber_id == ^subscriber.id and d.period == ^period
    )
  end

  # the unique (subscriber, period) index turns a second attempt into a
  # no-op insert, which comes back without an id
  defp reserve(subscriber, period, frequency, posts) do
    Repo.insert(
      %DigestSend{
        subscriber_id: subscriber.id,
        period: period,
        frequency: frequency,
        post_ids: Enum.map(posts, & &1.id),
        sent_at: DateTime.utc_now()
      },
      on_conflict: :nothing,
      conflict_target: [:subscriber_id, :period]
    )
  end
end
