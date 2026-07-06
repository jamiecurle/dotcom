defmodule JamieWeb.FeedControllerTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  describe "GET /feed.xml" do
    test "returns atom+xml content type", %{conn: conn} do
      conn = get(conn, ~p"/feed.xml")
      assert response_content_type(conn, :xml) =~ "application/atom+xml"
    end

    test "includes published posts", %{conn: conn} do
      {:ok, post} =
        ContentFixtures.post_attrs(title: "A Published Post", status: :published)
        |> Content.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ post.title
      assert body =~ post.slug
    end

    test "excludes draft posts", %{conn: conn} do
      {:ok, post} =
        ContentFixtures.post_attrs(title: "A Draft Post", status: :draft)
        |> Content.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      refute body =~ post.title
      refute body =~ post.slug
    end

    test "excludes hidden posts", %{conn: conn} do
      {:ok, post} =
        ContentFixtures.post_attrs(title: "A Hidden Post", status: :draft)
        |> Content.create_post()

      {:ok, post} = Content.update_post(post, %{status: :hidden})

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      refute body =~ post.title
      refute body =~ post.slug
    end

    test "only published posts appear when mix of statuses exist", %{conn: conn} do
      {:ok, published} =
        ContentFixtures.post_attrs(title: "Published One", status: :published)
        |> Content.create_post()

      {:ok, draft} =
        ContentFixtures.post_attrs(title: "Draft One", status: :draft)
        |> Content.create_post()

      {:ok, hidden_draft} =
        ContentFixtures.post_attrs(title: "Hidden One", status: :draft)
        |> Content.create_post()

      {:ok, hidden} = Content.update_post(hidden_draft, %{status: :hidden})

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
        ContentFixtures.post_attrs(
          title: "Post with <special> & 'chars'",
          status: :published
        )
        |> Content.create_post()

      conn = get(conn, ~p"/feed.xml")
      body = response(conn, 200)

      assert body =~ "&lt;special&gt;"
      assert body =~ "&amp;"
    end
  end
end
