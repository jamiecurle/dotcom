defmodule JamieWeb.ContentLive.PostTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  defp published_post(_) do
    {:ok, post} =
      ContentFixtures.post_attrs(status: :published) |> Content.create_post()

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
