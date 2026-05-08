defmodule JamieWeb.PageController do
  use JamieWeb, :controller

  alias JamieWeb.MarkdownRenderer

  def health(conn, _params) do
    conn
    |> put_root_layout(html: false)
    |> render(:health)
  end

  def about(conn, _params), do: render_static(conn, :about)
  def privacy(conn, _params), do: render_static(conn, :privacy)
  def projects(conn, _params), do: render_static(conn, :projects)

  defp render_static(conn, page) do
    conn
    |> assign(:content, MarkdownRenderer.static_page_html(page))
    |> render(:static)
  end
end
