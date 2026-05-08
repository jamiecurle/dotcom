defmodule JamieWeb.PageControllerTest do
  use JamieWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about")
    assert html_response(conn, 200) =~ "About"
  end

  test "GET /privacy", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    assert html_response(conn, 200) =~ "Privacy"
  end

  test "GET /projects", %{conn: conn} do
    conn = get(conn, ~p"/projects")
    assert html_response(conn, 200) =~ "Projects"
  end
end
