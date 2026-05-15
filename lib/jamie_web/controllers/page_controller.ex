defmodule JamieWeb.PageController do
  use JamieWeb, :controller

  alias JamieWeb.MarkdownRenderer

  def health(conn, _params) do
    conn
    |> put_root_layout(html: false)
    |> render(:health)
  end

  def home(conn, _params) do
    conn
    |> assign(:body_id, "home")
    |> assign(:page_title, "Hello")
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
