defmodule JamieWeb.PostMarkdownControllerTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures

  defp create_post(attrs) do
    {:ok, post} = attrs |> BlogFixtures.post_attrs() |> Blog.create_post()
    post
  end

  describe "GET /posts/:slug.md" do
    test "serves text/markdown for a published post", %{conn: conn} do
      post = create_post(title: "Hello World", status: :published)

      conn = get(conn, ~p"/posts/#{post.slug}/markdown")

      assert response_content_type(conn, :md) =~ "text/markdown"
      assert get_resp_header(conn, "cache-control") == ["public, max-age=3600"]
    end

    test "body is yaml front matter followed by raw markdown", %{conn: conn} do
      post =
        create_post(
          title: "A Real Post",
          description: "About things",
          markdown: "# Body\n\nSome content here.",
          status: :published
        )

      body = conn |> get(~p"/posts/#{post.slug}/markdown") |> response(200)

      assert String.starts_with?(body, "---\n")
      assert body =~ "title: #{post.title}"
      assert body =~ "description: #{post.description}"
      assert body =~ "url: #{JamieWeb.Endpoint.url()}/posts/#{post.slug}"
      assert body =~ "author: Jamie Curle"
      assert body =~ "copyright: Copyright Jamie Curle. All rights reserved."

      assert body =~
               "license: Reading and summarising permitted. Reproduction and AI training prohibited."

      [_open, _frontmatter, after_close] = String.split(body, "---\n", parts: 3)
      assert String.trim_leading(after_close) == post.markdown
    end

    test "front matter includes published_on and edited_on dates", %{conn: conn} do
      post = create_post(status: :published)

      body = conn |> get(~p"/posts/#{post.slug}/markdown") |> response(200)

      assert body =~ "published_on: #{post.published_on}"
      assert body =~ "edited_on: #{post.edited_on}"
    end

    test "returns 404 for a draft post", %{conn: conn} do
      post = create_post(status: :draft)

      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/#{post.slug}/markdown")
      end
    end

    test "returns 404 for a hidden post", %{conn: conn} do
      draft = create_post(status: :draft)
      {:ok, hidden} = Blog.update_post(draft, %{status: :hidden})

      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/#{hidden.slug}/markdown")
      end
    end

    test "returns 404 when slug does not exist", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/posts/does-not-exist/markdown")
      end
    end
  end
end
