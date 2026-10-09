defmodule JamieWeb.McpControllerTest do
  use JamieWeb.ConnCase, async: true

  import Jamie.AccountsFixtures

  alias Jamie.Accounts
  alias Jamie.Accounts.Scope
  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  @host "stekpi.test"

  setup %{conn: conn} do
    scope = Scope.for_user(user_fixture())
    {token, _} = Accounts.create_mcp_token(scope)

    {:ok, post} =
      Content.create_post(
        ContentFixtures.post_attrs(title: "Tree surgery", markdown: "Oaks live for 1000 years.\n")
      )

    conn =
      conn
      |> Map.put(:host, @host)
      |> put_req_header("authorization", "Bearer " <> token)
      |> put_req_header("content-type", "application/json")

    %{conn: conn, scope: scope, post: post}
  end

  defp rpc(conn, method, params \\ %{}) do
    body = Jason.encode!(%{jsonrpc: "2.0", id: 1, method: method, params: params})
    post(conn, "/mcp", body)
  end

  defp call_tool(conn, name, args) do
    %{"result" => result} =
      conn |> rpc("tools/call", %{name: name, arguments: args}) |> json_response(200)

    case result do
      %{"isError" => false, "content" => [%{"text" => text}]} -> {:ok, Jason.decode!(text)}
      %{"isError" => true, "content" => [%{"text" => text}]} -> {:error, text}
    end
  end

  describe "network gate" do
    test "the public hostname gets a 404", %{conn: conn} do
      assert conn |> Map.put(:host, "jamiecurle.com") |> rpc("ping") |> response(404)
    end

    test "requests that came through Cloudflare get a 404", %{conn: conn} do
      assert conn |> put_req_header("cf-ray", "abc-LHR") |> rpc("ping") |> response(404)
    end
  end

  describe "authentication" do
    test "no token is a 401", %{conn: conn} do
      assert conn |> delete_req_header("authorization") |> rpc("ping") |> response(401)
    end

    test "a bad token is a 401", %{conn: conn} do
      assert conn
             |> put_req_header("authorization", "Bearer nope")
             |> rpc("ping")
             |> response(401)
    end

    test "a browser session cookie isn't enough", %{conn: conn} do
      conn = conn |> delete_req_header("authorization") |> log_in_user(user_fixture())
      assert conn |> rpc("ping") |> response(401)
    end
  end

  describe "protocol" do
    test "initialize negotiates a version and offers tools", %{conn: conn} do
      assert %{
               "result" => %{"protocolVersion" => "2025-03-26", "capabilities" => %{"tools" => _}}
             } =
               conn |> rpc("initialize", %{protocolVersion: "2025-03-26"}) |> json_response(200)
    end

    test "notifications are acknowledged with 202", %{conn: conn} do
      body = Jason.encode!(%{jsonrpc: "2.0", method: "notifications/initialized"})
      assert conn |> post("/mcp", body) |> response(202) == ""
    end

    test "tools/list returns the tools", %{conn: conn} do
      %{"result" => %{"tools" => tools}} = conn |> rpc("tools/list") |> json_response(200)

      assert Enum.map(tools, & &1["name"]) ==
               ~w(list_posts get_post search_posts suggest_edit list_suggestions)
    end

    test "unknown methods are a JSON-RPC error", %{conn: conn} do
      assert %{"error" => %{"code" => -32_601}} =
               conn |> rpc("resources/list") |> json_response(200)
    end

    test "batches are rejected", %{conn: conn} do
      assert conn |> post("/mcp", "[]") |> json_response(400)
    end

    test "GET has no stream", %{conn: conn} do
      assert conn |> get("/mcp") |> response(405)
    end
  end

  describe "tools" do
    test "list_posts and get_post read drafts too", %{conn: conn, post: post} do
      assert {:ok, %{"posts" => [%{"id" => id, "status" => "draft"}]}} =
               call_tool(conn, "list_posts", %{})

      assert id == post.id

      assert {:ok, %{"markdown" => "Oaks live for 1000 years.\n", "pending_suggestions" => 0}} =
               call_tool(conn, "get_post", %{id: post.id})

      assert {:ok, %{"id" => ^id}} = call_tool(conn, "get_post", %{slug: post.slug})
      assert {:error, _} = call_tool(conn, "get_post", %{id: -1})
    end

    test "search_posts matches markdown, with LIKE wildcards taken literally", %{conn: conn} do
      assert {:ok, %{"posts" => [_]}} = call_tool(conn, "search_posts", %{query: "1000 YEARS"})
      assert {:ok, %{"posts" => []}} = call_tool(conn, "search_posts", %{query: "%%"})
    end

    test "suggest_edit files a suggestion and leaves the post alone", %{conn: conn, post: post} do
      args = %{
        post_id: post.id,
        old_string: "1000 years",
        new_string: "500 years",
        reason: "fact"
      }

      assert {:ok, %{"suggestion" => %{"status" => "pending"}}} =
               call_tool(conn, "suggest_edit", args)

      assert Content.get_post!(post.id).markdown == post.markdown

      assert {:ok, %{"suggestions" => [%{"new_string" => "500 years"}]}} =
               call_tool(conn, "list_suggestions", %{post_id: post.id})
    end

    test "suggest_edit explains mismatches", %{conn: conn, post: post} do
      args = %{post_id: post.id, old_string: "elms", new_string: "ash", reason: "x"}
      assert {:error, "old_string was not found" <> _} = call_tool(conn, "suggest_edit", args)

      assert {:error, _} = call_tool(conn, "suggest_edit", %{post_id: "1; drop"})
    end

    test "there is no tool to change a post directly", %{conn: conn, post: post} do
      assert {:error, "Unknown tool" <> _} =
               call_tool(conn, "update_post", %{id: post.id, status: "hidden"})
    end
  end
end
