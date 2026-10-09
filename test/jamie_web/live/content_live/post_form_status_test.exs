defmodule JamieWeb.ContentLive.PostFormStatusTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup :register_and_log_in_user

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :draft))
    %{post: post}
  end

  test "the current status is the chosen segment", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    assert has_element?(view, "#post-status-draft[checked].btn-neutral")
    refute has_element?(view, "#post-status-published[checked]")
    assert has_element?(view, "#post-status", "Not published yet")
  end

  test "choosing a status recolours it and saving publishes", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    view |> form("#editor-form", post: %{status: "published"}) |> render_change()
    assert has_element?(view, "#post-status-published[checked].btn-success")

    view |> form("#editor-form", post: %{status: "published"}) |> render_submit()

    saved = Content.get_post!(post.id)
    assert saved.status == :published
    assert has_element?(view, "#post-status", "Published")
  end
end
