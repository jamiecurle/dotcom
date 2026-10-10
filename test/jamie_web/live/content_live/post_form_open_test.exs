defmodule JamieWeb.ContentLive.PostFormOpenTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup :register_and_log_in_user

  test "opens the post on its own in a new tab", %{conn: conn} do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs())
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    assert has_element?(
             view,
             ~s|#open-post[href="/posts/#{post.slug}?preview=true"][target="_blank"]|
           )
  end

  test "a draft opens too, without the edit button", %{conn: conn} do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :draft))
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}?preview=true")

    assert has_element?(view, "h1.page-title", post.title)
    refute has_element?(view, "#edit-post")
  end

  test "a new post has nothing to open yet", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/new")
    refute has_element?(view, "#open-post")
  end
end
