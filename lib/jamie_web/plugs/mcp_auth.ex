defmodule JamieWeb.Plugs.McpAuth do
  @moduledoc """
  Authenticates `Authorization: Bearer <token>` against the MCP tokens
  managed at `/office/mcp`, assigning `current_scope` and `mcp_token_id`.

  There are no cookies or sessions on this path, so there is nothing for
  CSRF to ride on.
  """
  import Plug.Conn

  alias Jamie.Accounts
  alias Jamie.Accounts.Scope

  def init(opts), do: opts

  def call(conn, _opts) do
    with ["Bearer " <> token] <- get_req_header(conn, "authorization"),
         {user, user_token} <- Accounts.get_user_by_mcp_token(String.trim(token)) do
      conn
      |> assign(:current_scope, Scope.for_user(user))
      |> assign(:mcp_token_id, user_token.id)
    else
      _ ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(401, ~s({"error":"unauthorized"}))
        |> halt()
    end
  end
end
