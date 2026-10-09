defmodule JamieWeb.ContentLive.PostFormMergeTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  @markdown "The cat sat on the mat.\nSecond line here.\nThird line.\n"

  setup :register_and_log_in_user

  setup %{scope: scope} do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(markdown: @markdown))

    {:ok, suggestion} =
      Content.suggest_post_edit(scope, post.id, %{old_string: "cat sat", new_string: "cat sits"})

    %{post: post, suggestion: suggestion}
  end

  defp accept(scope, suggestion), do: {:ok, _} = Content.accept_suggestion(scope, suggestion.id)

  test "a clean editor takes the accepted change and can save straight after", %{
    conn: conn,
    scope: scope,
    post: post,
    suggestion: suggestion
  } do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    accept(scope, suggestion)

    assert has_element?(view, "#editor-form textarea", "The cat sits on the mat.")
    assert_push_event(view, "set-markdown", %{markdown: "The cat sits on the mat." <> _})

    view |> form("#editor-form", post: %{title: "New title"}) |> render_submit()

    refute render(view) =~ "changed in another tab"
    saved = Content.get_post!(post.id)
    assert saved.title == "New title"
    assert saved.markdown =~ "The cat sits on the mat."
  end

  test "unsaved work elsewhere in the post is kept and merged", %{
    conn: conn,
    scope: scope,
    post: post,
    suggestion: suggestion
  } do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    draft = @markdown <> "A paragraph I'm writing.\n"
    view |> form("#editor-form", post: %{markdown: draft}) |> render_change()

    accept(scope, suggestion)

    merged =
      "The cat sits on the mat.\nSecond line here.\nThird line.\nA paragraph I'm writing.\n"

    assert_push_event(view, "set-markdown", %{markdown: ^merged})

    # keep editing, then save: no conflict, both changes land
    view |> form("#editor-form", post: %{markdown: merged}) |> render_submit()

    refute render(view) =~ "changed in another tab"
    assert Content.get_post!(post.id).markdown == merged
  end

  test "editing the same words is a conflict and the draft is kept", %{
    conn: conn,
    scope: scope,
    post: post,
    suggestion: suggestion
  } do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    draft = String.replace(@markdown, "cat sat", "cat stood")
    view |> form("#editor-form", post: %{markdown: draft}) |> render_change()

    accept(scope, suggestion)

    assert render(view) =~ "same place you&#39;re editing"
    assert has_element?(view, "#editor-form textarea", "cat stood")
  end
end
