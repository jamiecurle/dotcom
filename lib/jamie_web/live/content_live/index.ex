defmodule JamieWeb.ContentLive.Index do
  use JamieWeb, :live_view

  alias Jamie.Content.{Note, Post}

  @months ~w(January February March April May June July August September October November December)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply,
     socket |> assign(:body_id, "blog") |> assign_listing(socket.assigns.live_action, params)}
  end

  defp assign_listing(socket, :index, _params) do
    socket
    |> assign_entries(Jamie.Content.published_posts())
    |> assign(:page_title, "Archive")
    |> assign(:page_description, "Writing on software, woodland, and the workshop.")
  end

  # A tag's page is the archive cut down to that tag, posts and notes mixed
  # together. A tag with nothing published under it is a 404, the same as a
  # tag that doesn't exist.
  defp assign_listing(socket, :tag, %{"slug" => slug}) do
    tag = Jamie.Tags.get_tag_by_slug!(slug)

    case Jamie.Tags.published_content(tag) do
      [] ->
        raise Ecto.NoResultsError, queryable: Jamie.Tags.Tag

      entries ->
        socket
        |> assign_entries(entries)
        |> assign(:page_title, tag.title)
        |> assign(:page_description, "Writing tagged #{tag.title}.")
    end
  end

  # entries are Post and Note structs, newest first
  defp assign_entries(socket, entries) do
    socket
    |> assign(:archive, archive(entries))
    |> assign(:count, count(entries))
  end

  # The archive borrows its parts from the other two pages: the cyan
  # masthead and margin index from a post, the dated list from the homepage.
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <header class="masthead">
        <div class="post-meta">
          <span>{@count}</span>
          <span :if={@archive != []}>Since {@archive |> List.last() |> elem(0)}</span>
        </div>
        <h1 class="page-title">{@page_title}</h1>
        <p class="standfirst">{@page_description}</p>
      </header>

      <section class="page-content archive">
        <aside :if={@archive != []} class="margin-nav">
          <nav aria-labelledby="years-title">
            <h2 id="years-title">Years</h2>
            <ol>
              <li :for={{year, entries} <- @archive}>
                <a href={"#year-#{year}"}><span>{year}</span><small>{length(entries)}</small></a>
              </li>
            </ol>
          </nav>
        </aside>

        <section
          :for={{year, entries} <- @archive}
          id={"year-#{year}"}
          class="writing-list archive-year"
        >
          <h2>
            <span class="year">{year}</span>
            <span class="count">{count(entries)}</span>
          </h2>
          <ol class="writing-index">
            <li :for={entry <- entries}>
              <.link href={path(entry)} id={dom_id(entry)}>
                <time datetime={Date.to_iso8601(entry.published_on)}>
                  {entry.published_on.day}{format(entry.published_on.day)} {month_name(
                    entry.published_on.month
                  )}
                </time>
                <span class="title">
                  <span>{entry.title}</span>
                  <small :if={match?(%Note{}, entry)} class="kind">Note</small>
                </span>
              </.link>
            </li>
          </ol>
        </section>
      </section>
    </Layouts.app>
    """
  end

  def format(number) when rem(number, 100) in [11, 12, 13], do: "th"
  def format(number) when rem(number, 10) in [11, 12, 13], do: "th"
  def format(number) when rem(number, 10) == 1, do: "st"
  def format(number) when rem(number, 10) == 2, do: "nd"
  def format(number) when rem(number, 10) == 3, do: "rd"
  def format(_number), do: "th"

  defp path(%Post{slug: slug}), do: ~p"/posts/#{slug}"
  defp path(%Note{id: id}), do: ~p"/notes/#{id}"

  defp dom_id(%Post{id: id}), do: "post-#{id}"
  defp dom_id(%Note{id: id}), do: "note-#{id}"

  # "12 posts", or "12 posts, 3 notes" once notes are in the mix
  defp count(entries) do
    notes = Enum.count(entries, &match?(%Note{}, &1))
    posts = length(entries) - notes

    case {posts, notes} do
      {_, 0} -> plural(posts, "post")
      {0, _} -> plural(notes, "note")
      _ -> plural(posts, "post") <> ", " <> plural(notes, "note")
    end
  end

  defp plural(1, noun), do: "1 #{noun}"
  defp plural(n, noun), do: "#{n} #{noun}s"

  # newest year first; entries already arrive newest first
  defp archive(entries) do
    entries
    |> Enum.group_by(& &1.published_on.year)
    |> Enum.sort_by(fn {year, _} -> year end, :desc)
  end

  defp month_name(n), do: Enum.at(@months, n - 1)
end
