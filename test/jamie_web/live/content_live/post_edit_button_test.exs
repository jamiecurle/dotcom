defmodule JamieWeb.ContentLive.PostEditButtonTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup do
    {:ok, post} =
      ContentFixtures.post_attrs(status: :published) |> Content.create_post()

    %{post: post}
  end

  test "signed out, there's no edit button", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

    refute has_element?(view, "#edit-post")
  end

  describe "signed in" do
    setup :register_and_log_in_user

    test "the edit button sits in the masthead and opens the editor", %{
      conn: conn,
      post: post
    } do
      {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

      assert has_element?(
               view,
               "header.masthead > a#edit-post[href='/office/posts/#{post.id}']"
             )
    end
  end
end
