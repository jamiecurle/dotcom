defmodule JamieWeb.BlogLive.Index do
  use JamieWeb, :live_view

  @months ~w(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec)

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    archive = Jamie.Blog.published_posts() |> archive()

    socket =
      socket
      |> assign(:body_id, "post")
      |> assign(:archive, archive)
      |> assign(:page_title, "Archive")
      |> assign(:page_description, "Writing on software, woodland, and the workshop.")

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <h1 class="page-title">Archive</h1>
      <div class="archive">
        <section :for={{year, months} <- @archive} class="archive-year">
          <h2 class="archive-year-label">{year}</h2>
          <div class="archive-year-months">
            <section :for={{month, posts} <- months} class="archive-month">
              <h3 class="archive-month-label">{month_name(month)}</h3>
              <ul class="archive-posts">
                <li :for={post <- posts} class="post-card">
                  <.link href={~p"/posts/#{post.slug}"}>{post.title}</.link>
                  <time datetime="{post.published_on}">{human_date(post.published_on)}</time>
                </li>
              </ul>
            </section>
          </div>
        </section>
      </div>
    </Layouts.app>
    """
  end

  defp human_date(date) do
    Calendar.strftime(date, "%a %-d") <> format(date.day)
  end

  def format(number) when rem(number, 100) in [11, 12, 13], do: "th"
  def format(number) when rem(number, 10) in [11, 12, 13], do: "th"
  def format(number) when rem(number, 10) == 1, do: "st"
  def format(number) when rem(number, 10) == 2, do: "nd"
  def format(number) when rem(number, 10) == 3, do: "rd"
  def format(_number), do: "th"

  defp archive(posts) do
    posts
    |> Enum.group_by(& &1.published_on.year)
    |> Enum.sort_by(fn {year, _} -> year end, :desc)
    |> Enum.map(fn {year, year_posts} ->
      months =
        year_posts
        |> Enum.group_by(& &1.published_on.month)
        |> Enum.sort_by(fn {month, _} -> month end, :desc)

      {year, months}
    end)
  end

  defp month_name(n), do: Enum.at(@months, n - 1)
end
