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

  describe ~s(<link rel="alternate" type="text/markdown">) do
    test "is present on pages with a markdown rendering", %{conn: conn} do
      for path <- [~p"/", ~p"/about", ~p"/privacy", ~p"/projects"] do
        body = conn |> get(path) |> html_response(200)
        assert body =~ ~s(rel="alternate")
        assert body =~ ~s(type="text/markdown")
        assert body =~ ~s(href="#{path}")
        assert body =~ ~s(title="LLM-readable version")
      end
    end

    test "is absent on pages without a markdown rendering", %{conn: conn} do
      body = conn |> get(~p"/users/log-in") |> html_response(200)
      refute body =~ ~s(type="text/markdown")
    end
  end
end
