defmodule JamieWeb.ContentLive.PostFormModesTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup :register_and_log_in_user

  setup %{scope: scope} do
    {:ok, post} =
      Content.create_post(ContentFixtures.post_attrs(title: "Cats", markdown: "The cat sat.\n"))

    {:ok, other} =
      Content.create_post(ContentFixtures.post_attrs(title: "Dogs", markdown: "A dog ran.\n"))

    {:ok, mine} =
      Content.suggest_post_edit(scope, post.id, %{old_string: "cat sat", new_string: "cat sits"})

    {:ok, theirs} =
      Content.suggest_post_edit(scope, other.id, %{old_string: "dog ran", new_string: "dog runs"})

    %{post: post, other: other, mine: mine, theirs: theirs}
  end

  describe "the editor's modes" do
    test "opens in writing mode", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

      assert has_element?(view, "#editor-mode-writing[aria-pressed='true']")
      refute has_element?(view, "#post-preview")
      refute has_element?(view, "#post-suggestions")
    end

    test "preview mode puts the live post beside the editor", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

      view |> element("#editor-mode-preview") |> render_click()

      assert has_element?(view, "#editor-mode-preview[aria-pressed='true']")
      assert has_element?(view, "#post-preview")
      refute has_element?(view, "#post-suggestions")
    end

    test "editing mode puts this post's suggestions beside the editor", %{
      conn: conn,
      post: post
    } do
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

      view |> element("#editor-mode-editing") |> render_click()

      assert has_element?(view, "#editor-mode-editing[aria-pressed='true']")
      refute has_element?(view, "#post-preview")

      assert has_element?(
               view,
               "#post-suggestions[src='/office/suggestions?post_id=#{post.id}&embed=true']"
             )
    end

    test "writing mode is just the editor", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

      view |> element("#editor-mode-writing") |> render_click()

      assert has_element?(view, "#editor-form")
      refute has_element?(view, "#post-preview")
      refute has_element?(view, "#post-suggestions")
    end

    test "a new post has no modes yet", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/office/posts/new")

      refute has_element?(view, "#editor-mode")
    end
  end

  describe "the embedded suggestions pane" do
    test "shows only this post's suggestions, without the office navbar", %{
      conn: conn,
      post: post,
      mine: mine,
      theirs: theirs
    } do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions?post_id=#{post.id}&embed=true")

      assert has_element?(view, "#suggestions-#{mine.id}")
      refute has_element?(view, "#suggestions-#{theirs.id}")
      refute has_element?(view, ".navbar")
    end

    test "ignores new suggestions for other posts", %{
      conn: conn,
      scope: scope,
      post: post,
      other: other
    } do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions?post_id=#{post.id}&embed=true")

      {:ok, later} =
        Content.suggest_post_edit(scope, other.id, %{old_string: "A dog", new_string: "The dog"})

      refute has_element?(view, "#suggestions-#{later.id}")
    end

    test "the full queue keeps its navbar and every post", %{
      conn: conn,
      mine: mine,
      theirs: theirs
    } do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions")

      assert has_element?(view, ".navbar")
      assert has_element?(view, "#suggestions-#{mine.id}")
      assert has_element?(view, "#suggestions-#{theirs.id}")
    end
  end
end
