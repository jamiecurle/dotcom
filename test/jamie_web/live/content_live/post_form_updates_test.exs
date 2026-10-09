defmodule JamieWeb.ContentLive.PostFormUpdatesTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup :register_and_log_in_user

  setup %{scope: scope} do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(markdown: "The cat sat.\n"))

    {:ok, suggestion} =
      Content.suggest_post_edit(scope, post.id, %{old_string: "cat sat", new_string: "cat sits"})

    %{post: post, suggestion: suggestion}
  end

  test "an editor with unsaved changes keeps them and warns", %{
    conn: conn,
    scope: scope,
    post: post,
    suggestion: suggestion
  } do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    view
    |> form("#editor-form", post: %{markdown: "The cat sat. My draft.\n"})
    |> render_change()

    {:ok, _} = Content.accept_suggestion(scope, suggestion.id)

    assert render(view) =~ "changed elsewhere"
    assert has_element?(view, "#editor-form textarea", "My draft.")
  end

  test "the editor's own saves don't trigger a reload", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    view
    |> form("#editor-form", post: %{markdown: "Saved here.\n"})
    |> render_submit()

    refute render(view) =~ "updated elsewhere"
    assert has_element?(view, "#editor-form textarea", "Saved here.")
  end
end
