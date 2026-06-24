defmodule JamieWeb.BlogLive.PostTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures

  defp published_post(_) do
    {:ok, post} =
      BlogFixtures.post_attrs(status: :published) |> Blog.create_post()

    %{post: post}
  end

  describe "og:image meta tag" do
    setup [:published_post]

    test "points at the post's generated image on R2", %{conn: conn, post: post} do
      {:ok, _view, html} = live(conn, "/posts/#{post.slug}")

      host = Application.get_env(:jamie, :images)[:host]
      expected = "https://#{host}/opengraph/#{post.og_hash}.png"

      assert html =~ ~s(property="og:image")
      assert html =~ expected
    end
  end
end
