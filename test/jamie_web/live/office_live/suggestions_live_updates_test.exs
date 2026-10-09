defmodule JamieWeb.OfficeLive.SuggestionsLiveUpdatesTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup :register_and_log_in_user

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(markdown: "The cat sat.\n"))
    %{post: post}
  end

  defp suggest(scope, post) do
    {:ok, suggestion} =
      Content.suggest_post_edit(scope, post.id, %{old_string: "cat sat", new_string: "cat sits"})

    suggestion
  end

  test "a new suggestion appears without a reload", %{conn: conn, scope: scope, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/suggestions")
    assert has_element?(view, "#suggestions-empty")

    suggestion = suggest(scope, post)

    assert has_element?(view, "#suggestions-#{suggestion.id} del", "cat sat")
  end

  test "a suggestion resolved elsewhere disappears", %{conn: conn, scope: scope, post: post} do
    suggestion = suggest(scope, post)
    {:ok, view, _html} = live(conn, ~p"/office/suggestions")
    assert has_element?(view, "#suggestions-#{suggestion.id}")

    {:ok, _} = Content.reject_suggestion(scope, suggestion.id)

    refute has_element?(view, "#suggestions-#{suggestion.id}")
  end
end
