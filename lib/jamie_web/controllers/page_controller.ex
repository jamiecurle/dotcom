defmodule JamieWeb.PageController do
  use JamieWeb, :controller

  alias Jamie.Content
  alias JamieWeb.MarkdownRenderer

  def health(conn, _params) do
    conn
    |> put_root_layout(html: false)
    |> render(:health)
  end

  def home(conn, _params) do
    posts =
      Content.latest_published_posts(10)

    conn
    |> assign(:posts, posts)
    |> assign(:body_id, "home")
    |> assign(:page_title, "Hello")
    |> put_resp_header("cache-control", "public, max-age=300")
    |> render(:home)
  end

  def about(conn, _params) do
    conn
    |> assign(:body_id, "about")
    |> render_static(:about, "About", "About Jamie Curle.")
  end

  def privacy(conn, _params),
    do: render_static(conn, :privacy, "Privacy", "Privacy policy for jamiecurle.com.")

  def projects(conn, _params),
    do: render_static(conn, :projects, "Projects", "Projects Jamie Curle is working on.")

  defp render_static(conn, page, title, description) do
    conn
    |> assign(:content, MarkdownRenderer.static_page_html(page))
    |> assign(:page_title, title)
    |> assign(:page_description, description)
    |> render(:static)
  end
end
