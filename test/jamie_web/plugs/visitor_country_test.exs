defmodule JamieWeb.Plugs.VisitorCountryTest do
  use JamieWeb.ConnCase, async: true

  alias JamieWeb.Plugs.VisitorCountry

  defp run(conn) do
    conn
    |> Plug.Test.init_test_session(%{})
    |> VisitorCountry.call(VisitorCountry.init([]))
  end

  test "stashes the country in both assigns and the session" do
    conn =
      build_conn(:get, "/")
      |> put_req_header("cf-ipcountry", "GB")
      |> run()

    assert conn.assigns.visitor_country == "GB"
    assert get_session(conn, "visitor_country") == "GB"
  end

  test "normalizes the header (XX/T1 sentinels become nil)" do
    conn =
      build_conn(:get, "/")
      |> put_req_header("cf-ipcountry", "XX")
      |> run()

    assert conn.assigns.visitor_country == nil
    assert get_session(conn, "visitor_country") == nil
  end

  test "stores nil when the header is absent" do
    conn = run(build_conn(:get, "/"))

    assert conn.assigns.visitor_country == nil
    assert get_session(conn, "visitor_country") == nil
  end
end
