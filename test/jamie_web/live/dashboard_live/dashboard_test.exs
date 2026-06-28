defmodule JamieWeb.OfficeLive.DashboardTest do
  use JamieWeb.ConnCase, async: true

  import Jamie.AccountsFixtures
  @url "/office/"

  describe "auth required tests" do
    setup do
      %{user: user_fixture()}
    end

    test "redirects if with a standard view", %{conn: conn} do
      conn = get(conn, @url)
      assert 302 == conn.status
      refute 200 == conn.status
    end

    test "renders if a user is logged in", %{conn: conn, user: user} do
      # auth the user
      conn =
        log_in_user(conn, user)
        |> get(@url)

      # it was a 200 and not a 302

      refute 302 == conn.status
      assert 200 == conn.status
    end
  end
end
