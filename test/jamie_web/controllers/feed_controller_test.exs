defmodule JamieWeb.FeedControllerTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures

  describe "GET /feed.xml" do
    test "returns atom+xml content type", %{conn: conn} do
      conn = get(conn, ~p"/feed.xml")
      assert response_content_type(conn, :xml) =~ "application/atom+xml"
    end

    test "includes published posts", %{conn: conn} do
      {:ok, post} =
        BlogFixtures.post_attrs(title: "A Published Post", status: :published)
        |> Blog.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ post.title
      assert body =~ post.slug
    end

    test "excludes draft posts", %{conn: conn} do
      {:ok, post} =
        BlogFixtures.post_attrs(title: "A Draft Post", status: :draft)
        |> Blog.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      refute body =~ post.title
      refute body =~ post.slug
    end

    test "excludes hidden posts", %{conn: conn} do
      {:ok, post} =
        BlogFixtures.post_attrs(title: "A Hidden Post", status: :draft)
        |> Blog.create_post()

      {:ok, post} = Blog.update_post(post, %{status: :hidden})

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      refute body =~ post.title
      refute body =~ post.slug
    end

    test "only published posts appear when mix of statuses exist", %{conn: conn} do
      {:ok, published} =
        BlogFixtures.post_attrs(title: "Published One", status: :published)
        |> Blog.create_post()

      {:ok, draft} =
        BlogFixtures.post_attrs(title: "Draft One", status: :draft)
        |> Blog.create_post()

      {:ok, hidden_draft} =
        BlogFixtures.post_attrs(title: "Hidden One", status: :draft)
        |> Blog.create_post()

      {:ok, hidden} = Blog.update_post(hidden_draft, %{status: :hidden})

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ published.title
      refute body =~ draft.title
      refute body =~ hidden.title
    end

    test "returns valid atom xml structure", %{conn: conn} do
      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ ~s(xmlns="http://www.w3.org/2005/Atom")
      assert body =~ "<feed"
      assert body =~ "</feed>"
    end

    test "escapes html in post content", %{conn: conn} do
      {:ok, _post} =
        BlogFixtures.post_attrs(
          title: "Post with <special> & 'chars'",
          status: :published
        )
        |> Blog.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "&lt;special&gt;"
      assert body =~ "&amp;"
    end
  end
end
