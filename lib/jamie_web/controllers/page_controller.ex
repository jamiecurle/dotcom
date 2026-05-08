defmodule JamieWeb.PageController do
  use JamieWeb, :controller

  def health(conn, _params) do
    conn
    |> put_root_layout(html: false)
    |> render(:health)
  end

  def about(conn, _params) do
    render(conn, :about)
  end

  def privacy(conn, _params) do
    render(conn, :privacy)
  end

  def projects(conn, _params) do
    render(conn, :projects)
  end
end
