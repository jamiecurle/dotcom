defmodule JamieWeb.McpController do
  @moduledoc """
  A minimal, stateless MCP server over Streamable HTTP.

  Only the tools capability is offered, so the whole protocol is a handful of
  JSON-RPC methods answered with plain JSON — no sessions, no SSE stream.
  Requests only reach here after `TailnetOnly` and `McpAuth` have passed.
  See https://modelcontextprotocol.io/specification for the protocol.
  """
  use JamieWeb, :controller

  require Logger

  alias JamieWeb.Mcp.Tools

  @protocol_versions ["2025-06-18", "2025-03-26", "2024-11-05"]

  @instructions """
  Tools for reviewing posts on jamiecurle.com. Read posts with list_posts, \
  search_posts and get_post. To propose a correction, use suggest_edit — it \
  never changes a post directly; Jamie reviews every suggestion by hand.\
  """

  # A JSON-RPC message with no id is a notification: acknowledge, no body.
  def handle(conn, %{"jsonrpc" => "2.0", "method" => _method} = message)
      when not is_map_key(message, "id") do
    send_resp(conn, 202, "")
  end

  def handle(conn, %{"jsonrpc" => "2.0", "id" => id, "method" => method} = message) do
    params = Map.get(message, "params", %{})

    case dispatch(conn, method, params) do
      {:ok, result} ->
        json(conn, %{jsonrpc: "2.0", id: id, result: result})

      {:error, code, msg} ->
        json(conn, %{jsonrpc: "2.0", id: id, error: %{code: code, message: msg}})
    end
  end

  # Batches were dropped from the spec in 2025-06-18, and anything else isn't
  # JSON-RPC at all.
  def handle(conn, _params) do
    conn
    |> put_status(400)
    |> json(%{jsonrpc: "2.0", id: nil, error: %{code: -32_600, message: "Invalid Request"}})
  end

  # We don't offer a server-to-client SSE stream, which the spec says to
  # signal with a 405 on GET.
  def stream(conn, _params) do
    conn
    |> put_resp_header("allow", "POST")
    |> send_resp(405, "")
  end

  defp dispatch(_conn, "initialize", params) do
    requested = params["protocolVersion"]
    version = if requested in @protocol_versions, do: requested, else: hd(@protocol_versions)

    {:ok,
     %{
       protocolVersion: version,
       capabilities: %{tools: %{}},
       serverInfo: %{name: "jamiecurle.com", version: "1.0.0"},
       instructions: @instructions
     }}
  end

  defp dispatch(_conn, "ping", _params), do: {:ok, %{}}

  defp dispatch(_conn, "tools/list", _params), do: {:ok, %{tools: Tools.list()}}

  defp dispatch(conn, "tools/call", %{"name" => name} = params) when is_binary(name) do
    args = Map.get(params, "arguments") || %{}
    scope = conn.assigns.current_scope

    # Every tool call is logged against the token that made it, so a leaked
    # token's activity can be traced and the token revoked.
    Logger.info(
      "mcp tools/call #{name} token_id=#{conn.assigns.mcp_token_id} user_id=#{scope.user.id}"
    )

    case Tools.call(scope, name, args) do
      {:ok, data} ->
        {:ok,
         %{content: [%{type: "text", text: Jason.encode!(data, pretty: true)}], isError: false}}

      {:error, message} ->
        {:ok, %{content: [%{type: "text", text: message}], isError: true}}
    end
  end

  defp dispatch(_conn, "tools/call", _params), do: {:error, -32_602, "Invalid params"}

  defp dispatch(_conn, method, _params), do: {:error, -32_601, "Method not found: #{method}"}
end
