defmodule JamieWeb.PageController do
  use JamieWeb, :controller

  alias Jamie.Analytics
  alias Jamie.Content
  alias JamieWeb.MarkdownRenderer

  def health(conn, _params) do
    conn
    |> put_root_layout(html: false)
    |> render(:health)
  end

  def home(conn, _params) do
    # the newest post leads the page and the next nine are indexed beside
    # it in the photo; the twenty after that go in the band underneath
    {lead, rest, earlier} =
      case Content.latest_published_posts(30) do
        [lead | rest] ->
          {rest, earlier} = Enum.split(rest, 9)
          {lead, rest, earlier}

        [] ->
          {nil, [], []}
      end

    conn
    |> assign(:lead, lead)
    |> assign(:rest, rest)
    |> assign(:earlier, earlier)
    |> assign(:popular, popular_posts())
    |> assign(:body_id, "home")
    |> assign(:page_title, "Hello")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> render(:home)
  end

  def about(conn, _params) do
    render_static(conn, :about, "About", "About Jamie Curle.",
      standfirst:
        "My guiding principle is to do things the hard way because it makes everything easy. Take the easy path and everything is hard. Framing is everything."
    )
  end

  def privacy(conn, _params),
    do: render_static(conn, :privacy, "Privacy", "Privacy policy for jamiecurle.com.")

  def projects(conn, _params),
    do: render_static(conn, :projects, "Projects", "Projects Jamie Curle is working on.")

  # The ten most read posts of the last ninety days. A handful of reads
  # isn't a ranking, so with fewer than five the list isn't shown at all.
  defp popular_posts do
    case Analytics.popular_posts(90, 10) do
      popular when length(popular) >= 5 -> popular
      _too_few -> []
    end
  end

  # The static pages are laid out like a post: masthead, numbered sections,
  # contents in the margin and some recent writing at the foot. The masthead
  # carries the title, so a leading `# Title` in the markdown is dropped from
  # the body (it stays in the markdown version of the page).
  defp render_static(conn, page, title, description, opts \\ []) do
    markdown = page |> MarkdownRenderer.static_page_markdown() |> drop_title()

    conn
    |> assign(:body_id, to_string(page))
    |> assign(:body_classes, ["page"])
    |> assign(:standfirst, opts[:standfirst])
    |> assign(:content, Jamie.Markdown.to_html!(markdown))
    |> assign(:toc, Jamie.Markdown.toc(markdown))
    |> assign(:reading_minutes, Jamie.Markdown.reading_minutes(markdown))
    |> assign(:more_posts, Content.latest_published_posts(3))
    |> assign(:page_title, title)
    |> assign(:page_description, description)
    |> render(:static)
  end

  defp drop_title(markdown), do: String.replace(markdown, ~r/\A\s*# [^\n]*\n/, "")
end
