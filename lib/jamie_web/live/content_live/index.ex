defmodule JamieWeb.ContentLive.Index do
  use JamieWeb, :live_view

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
    |> assign_posts(Jamie.Content.published_posts())
    |> assign(:page_title, "Archive")
    |> assign(:page_description, "Writing on software, woodland, and the workshop.")
  end

  # A tag's page is the archive cut down to that tag. A tag with nothing
  # published under it is a 404, the same as a tag that doesn't exist.
  defp assign_listing(socket, :tag, %{"slug" => slug}) do
    tag = Jamie.Tags.get_tag_by_slug!(slug)

    case Jamie.Tags.published_posts(tag) do
      [] ->
        raise Ecto.NoResultsError, queryable: Jamie.Tags.Tag

      posts ->
        socket
        |> assign_posts(posts)
        |> assign(:page_title, tag.title)
        |> assign(:page_description, "Writing tagged #{tag.title}.")
    end
  end

  defp assign_posts(socket, posts) do
    socket
    |> assign(:archive, archive(posts))
    |> assign(:post_count, length(posts))
  end

  # The archive borrows its parts from the other two pages: the cyan
  # masthead and margin index from a post, the dated list from the homepage.
  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <header class="masthead">
        <div class="post-meta">
          <span>{@post_count} posts</span>
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
              <li :for={{year, posts} <- @archive}>
                <a href={"#year-#{year}"}><span>{year}</span><small>{length(posts)}</small></a>
              </li>
            </ol>
          </nav>
        </aside>

        <section
          :for={{year, posts} <- @archive}
          id={"year-#{year}"}
          class="writing-list archive-year"
        >
          <h2>
            <span class="year">{year}</span>
            <span class="count">{length(posts)} posts</span>
          </h2>
          <ol class="writing-index">
            <li :for={post <- posts}>
              <.link href={~p"/posts/#{post.slug}"} id={"post-#{post.id}"}>
                <time datetime={Date.to_iso8601(post.published_on)}>
                  {post.published_on.day}{format(post.published_on.day)} {month_name(
                    post.published_on.month
                  )}
                </time>
                <span class="title"><span>{post.title}</span></span>
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

  # newest year first; posts already arrive newest first
  defp archive(posts) do
    posts
    |> Enum.group_by(& &1.published_on.year)
    |> Enum.sort_by(fn {year, _} -> year end, :desc)
  end

  defp month_name(n), do: Enum.at(@months, n - 1)
end
