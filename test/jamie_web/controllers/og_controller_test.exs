defmodule JamieWeb.OgControllerTest do
  use JamieWeb.ConnCase
  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures

  describe "GET /opengraph/:thing/:id" do
    setup do
      # create a post
      {:ok, post} = BlogFixtures.post_attrs() |> Blog.create_post()
      # done
      %{post: post}
    end

    test "404 if thing isn't supported", %{conn: conn} do
      conn = get(conn, ~p"/opengraph/blog/1")
      assert conn.status == 404
    end

    test "redirects if it is supported", %{conn: conn, post: post} do
      conn = get(conn, ~p"/opengraph/post/#{post.id}")
      assert redirected_to(conn, 302) =~ "/opengraph/"
    end
  end
end
