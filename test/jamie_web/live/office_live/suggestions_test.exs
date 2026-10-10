defmodule JamieWeb.OfficeLive.SuggestionsTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Content.PostSuggestion
  alias Jamie.Repo
  alias Jamie.Support.ContentFixtures

  test "requires login", %{conn: conn} do
    assert {:error, {:redirect, %{to: "/front-door/log-in"}}} =
             live(conn, ~p"/office/suggestions")
  end

  describe "logged in" do
    setup :register_and_log_in_user

    setup %{scope: scope} do
      {:ok, post} =
        Content.create_post(ContentFixtures.post_attrs(markdown: "The cat sat on the mat.\n"))

      {:ok, suggestion} =
        Content.suggest_post_edit(scope, post.id, %{old_string: "cat sat", new_string: "cat sits"})

      %{post: post, suggestion: suggestion}
    end

    test "each suggestion shows its id, as Claude refers to it", %{
      conn: conn,
      suggestion: suggestion
    } do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions")
      assert has_element?(view, "#suggestion-id-#{suggestion.id}", "##{suggestion.id}")
    end

    test "accepting applies the edit", %{conn: conn, post: post, suggestion: suggestion} do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions")
      assert has_element?(view, "#suggestions-#{suggestion.id} del", "cat sat")

      view |> element("#accept-suggestion-#{suggestion.id}") |> render_click()

      refute has_element?(view, "#suggestions-#{suggestion.id}")
      assert Content.get_post!(post.id).markdown == "The cat sits on the mat.\n"
    end

    test "rejecting leaves the post alone", %{conn: conn, post: post, suggestion: suggestion} do
      {:ok, view, _html} = live(conn, ~p"/office/suggestions")

      view |> element("#reject-suggestion-#{suggestion.id}") |> render_click()

      refute has_element?(view, "#suggestions-#{suggestion.id}")
      assert Repo.get!(PostSuggestion, suggestion.id).status == :rejected
      assert Content.get_post!(post.id).markdown == post.markdown
    end

    test "a stale suggestion is flagged and not applied", %{
      conn: conn,
      post: post,
      suggestion: suggestion
    } do
      {:ok, _} = Content.update_post(post, %{markdown: "Rewritten.\n"})
      {:ok, view, _html} = live(conn, ~p"/office/suggestions")

      view |> element("#accept-suggestion-#{suggestion.id}") |> render_click()

      refute has_element?(view, "#suggestions-#{suggestion.id}")
      assert Repo.get!(PostSuggestion, suggestion.id).status == :stale
      assert Content.get_post!(post.id).markdown == "Rewritten.\n"
    end
  end
end
