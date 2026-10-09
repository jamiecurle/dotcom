defmodule JamieWeb.OfficeLive.McpTokensTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Accounts

  test "requires login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/front-door/log-in"}}} = live(conn, ~p"/office/mcp")
  end

  describe "logged in" do
    setup :register_and_log_in_user

    test "creating a token shows it once", %{conn: conn, scope: scope} do
      {:ok, view, _html} = live(conn, ~p"/office/mcp")
      refute has_element?(view, "#new-mcp-token")

      view |> element("#create-mcp-token") |> render_click()

      assert has_element?(view, "#new-mcp-token")
      assert [token] = Accounts.list_mcp_tokens(scope)
      assert has_element?(view, "#mcp-token-#{token.id}")

      # a fresh page load no longer has the plaintext token
      {:ok, view, _html} = live(conn, ~p"/office/mcp")
      refute has_element?(view, "#new-mcp-token")
    end

    test "revoking removes the token", %{conn: conn, scope: scope} do
      {_encoded, token} = Accounts.create_mcp_token(scope)
      {:ok, view, _html} = live(conn, ~p"/office/mcp")

      view |> element("#revoke-mcp-token-#{token.id}") |> render_click()

      refute has_element?(view, "#mcp-token-#{token.id}")
      assert [] == Accounts.list_mcp_tokens(scope)
    end
  end
end
