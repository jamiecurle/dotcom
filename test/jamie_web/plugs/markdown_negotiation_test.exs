defmodule JamieWeb.Plugs.MarkdownNegotiationTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures

  defp create_post(attrs) do
    {:ok, post} = attrs |> BlogFixtures.blog_attrs() |> Blog.create_post()
    post
  end

  defp md_get(conn, path, accept \\ "text/markdown") do
    conn |> put_req_header("accept", accept) |> get(path)
  end

  describe "Accept: text/markdown" do
    test "GET / returns 200 markdown about-for-agents body", %{conn: conn} do
      llm_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "about.llm.md"])
      llm_body = File.read!(llm_path)

      conn = md_get(conn, ~p"/")

      assert conn.status == 200
      assert [ct] = get_resp_header(conn, "content-type")
      assert ct =~ "text/markdown"
      assert ct =~ "charset=utf-8"

      [tokens] = get_resp_header(conn, "x-markdown-tokens")
      assert {n, ""} = Integer.parse(tokens)
      assert n > 0

      assert conn.resp_body == llm_body
      assert conn.resp_body =~ "note for AI agents"
    end

    test "GET /posts/:slug for a published post returns markdown with front-matter", %{conn: conn} do
      post = create_post(title: "Negotiated", description: "Hi", status: :published)

      conn = md_get(conn, ~p"/posts/#{post.slug}")
      body = response(conn, 200)

      assert response_content_type(conn, :md) =~ "text/markdown"
      assert body =~ "title: #{post.title}"
      assert body =~ "url: #{JamieWeb.Endpoint.url()}/posts/#{post.slug}"
      assert body =~ "author: Jamie Curle"
      assert get_resp_header(conn, "x-markdown-tokens") != []
    end

    test "GET /posts/:slug for a draft falls through to HTML 404", %{conn: conn} do
      draft = create_post(status: :draft)

      assert_error_sent 404, fn ->
        md_get(conn, ~p"/posts/#{draft.slug}")
      end
    end

    test "GET /posts/:slug for a missing slug falls through to HTML 404", %{conn: conn} do
      assert_error_sent 404, fn ->
        md_get(conn, "/posts/does-not-exist")
      end
    end

    test "GET /about, /privacy, /projects each return non-empty markdown", %{conn: conn} do
      for path <- [~p"/about", ~p"/privacy", ~p"/projects"] do
        conn = md_get(conn, path)
        assert conn.status == 200
        assert response_content_type(conn, :md) =~ "text/markdown"
        assert byte_size(conn.resp_body) > 0
      end
    end

    test "GET /users/log-in falls through to HTML (unsupported path)", %{conn: conn} do
      conn = md_get(conn, ~p"/users/log-in")
      assert html_response(conn, 200)
    end

    test "GET /about serves the .llm.md variant when present", %{conn: conn} do
      llm_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "about.llm.md"])
      md_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "about.md"])
      llm_body = File.read!(llm_path)
      html_body = File.read!(md_path)

      conn = md_get(conn, ~p"/about")

      assert conn.status == 200
      assert response_content_type(conn, :md) =~ "text/markdown"
      assert conn.resp_body == llm_body
      refute conn.resp_body == html_body
      assert conn.resp_body =~ "note for AI agents"
    end

    test "GET /privacy with no .llm.md falls back to privacy.md", %{conn: conn} do
      md_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "privacy.md"])
      llm_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "privacy.llm.md"])
      refute File.exists?(llm_path), "test assumes no privacy.llm.md is present"

      conn = md_get(conn, ~p"/privacy")

      assert conn.status == 200
      assert response_content_type(conn, :md) =~ "text/markdown"
      assert conn.resp_body == File.read!(md_path)
    end
  end

  describe "non-markdown requests pass through to HTML" do
    test "no accept header serves HTML", %{conn: conn} do
      conn = get(conn, ~p"/about")
      assert html_response(conn, 200) =~ "About"
    end

    test "Accept: text/html serves HTML", %{conn: conn} do
      conn =
        conn
        |> put_req_header("accept", "text/html")
        |> get(~p"/")

      assert html_response(conn, 200)
    end

    test "Accept: */* does not trigger markdown", %{conn: conn} do
      conn = md_get(conn, ~p"/about", "*/*")
      assert html_response(conn, 200) =~ "About"
    end

    test "Accept with html preferred over markdown serves HTML", %{conn: conn} do
      conn = md_get(conn, ~p"/about", "text/html, text/markdown;q=0.5")
      assert html_response(conn, 200) =~ "About"
    end

    test "Accept with markdown preferred over html serves markdown", %{conn: conn} do
      conn = md_get(conn, ~p"/about", "text/html;q=0.5, text/markdown;q=0.9")
      assert conn.status == 200
      assert response_content_type(conn, :md) =~ "text/markdown"
    end

    test "POST with Accept: text/markdown is downgraded so the form still posts" do
      alias JamieWeb.Plugs.MarkdownNegotiation

      conn =
        build_conn(:post, "/users/log-in", %{})
        |> put_req_header("accept", "text/markdown")
        |> MarkdownNegotiation.call(MarkdownNegotiation.init([]))

      refute conn.halted
      assert conn.status == nil
      assert get_req_header(conn, "accept") == ["text/html"]
    end
  end

  describe "prefers_markdown?/1" do
    alias JamieWeb.Plugs.MarkdownNegotiation

    test "true for explicit text/markdown" do
      conn = build_conn() |> put_req_header("accept", "text/markdown")
      assert MarkdownNegotiation.prefers_markdown?(conn)
    end

    test "false for missing accept" do
      refute MarkdownNegotiation.prefers_markdown?(build_conn())
    end

    test "false for */*" do
      conn = build_conn() |> put_req_header("accept", "*/*")
      refute MarkdownNegotiation.prefers_markdown?(conn)
    end

    test "false when html outranks markdown" do
      conn =
        build_conn()
        |> put_req_header("accept", "text/html, text/markdown;q=0.1")

      refute MarkdownNegotiation.prefers_markdown?(conn)
    end
  end
end
