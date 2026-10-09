defmodule Jamie.PostSuggestionsTest do
  use Jamie.DataCase, async: true

  import Jamie.AccountsFixtures

  alias Jamie.Accounts.Scope
  alias Jamie.Content
  alias Jamie.Content.{PostRevision, PostSuggestion}
  alias Jamie.Support.ContentFixtures

  setup do
    {:ok, post} =
      Content.create_post(ContentFixtures.post_attrs(markdown: "The cat sat on the mat.\n"))

    %{post: post, scope: Scope.for_user(user_fixture())}
  end

  defp suggest(scope, post, old, new) do
    Content.suggest_post_edit(scope, post.id, %{
      "old_string" => old,
      "new_string" => new,
      "reason" => "typo"
    })
  end

  describe "replace_once/3" do
    test "replaces a unique match" do
      assert {:ok, "a dog b"} = Content.replace_once("a cat b", "cat", "dog")
    end

    test "refuses missing and ambiguous matches" do
      assert {:error, :not_found} = Content.replace_once("a cat b", "cow", "dog")
      assert {:error, :ambiguous} = Content.replace_once("the cat the", "the", "a")
    end
  end

  describe "suggest_post_edit/3" do
    test "files a pending suggestion without touching the post", %{scope: scope, post: post} do
      assert {:ok, %PostSuggestion{status: :pending}} =
               suggest(scope, post, "cat sat", "cat sits")

      assert Content.get_post!(post.id).markdown == post.markdown
    end

    test "rejects text that isn't in the post exactly once", %{scope: scope, post: post} do
      assert {:error, :not_found} = suggest(scope, post, "dog", "cat")
      assert {:error, :ambiguous} = suggest(scope, post, "at", "og")
    end

    test "allows deletions but not no-ops", %{scope: scope, post: post} do
      assert {:ok, %PostSuggestion{new_string: ""}} = suggest(scope, post, " on the mat", "")
      assert {:error, %Ecto.Changeset{}} = suggest(scope, post, "cat", "cat")
    end
  end

  describe "accept_suggestion/2" do
    test "applies the edit and records a revision", %{scope: scope, post: post} do
      {:ok, suggestion} = suggest(scope, post, "cat sat", "cat sits")

      assert {:ok, %PostSuggestion{status: :accepted, resolved_at: %DateTime{}}} =
               Content.accept_suggestion(scope, suggestion.id)

      assert Content.get_post!(post.id).markdown == "The cat sits on the mat.\n"
      assert Repo.exists?(from r in PostRevision, where: r.post_id == ^post.id)
    end

    test "marks the suggestion stale when the post moved on", %{scope: scope, post: post} do
      {:ok, suggestion} = suggest(scope, post, "cat sat", "cat sits")
      {:ok, _} = Content.update_post(post, %{markdown: "The dog sat on the mat.\n"})

      assert {:error, :stale} = Content.accept_suggestion(scope, suggestion.id)
      assert Repo.get!(PostSuggestion, suggestion.id).status == :stale
      assert Content.get_post!(post.id).markdown == "The dog sat on the mat.\n"
    end

    test "won't apply a suggestion twice", %{scope: scope, post: post} do
      {:ok, suggestion} = suggest(scope, post, "cat sat", "cat sits")
      {:ok, _} = Content.accept_suggestion(scope, suggestion.id)

      assert {:error, :not_pending} = Content.accept_suggestion(scope, suggestion.id)
    end
  end

  describe "reject_suggestion/2" do
    test "leaves the post alone", %{scope: scope, post: post} do
      {:ok, suggestion} = suggest(scope, post, "cat sat", "cat sits")

      assert {:ok, %PostSuggestion{status: :rejected}} =
               Content.reject_suggestion(scope, suggestion.id)

      assert Content.get_post!(post.id).markdown == post.markdown
      assert {:error, :not_pending} = Content.accept_suggestion(scope, suggestion.id)
    end
  end

  test "list_suggestions/2 filters by status and post", %{scope: scope, post: post} do
    {:ok, a} = suggest(scope, post, "cat sat", "cat sits")
    {:ok, b} = suggest(scope, post, "mat", "rug")
    {:ok, _} = Content.reject_suggestion(scope, b.id)

    assert [%{id: id}] = Content.list_suggestions(scope, status: :pending)
    assert id == a.id
    assert length(Content.list_suggestions(scope, post_id: post.id)) == 2
  end
end
