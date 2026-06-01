defmodule Jamie.Blog.PostRevisionsTest do
  use Jamie.DataCase, async: true

  alias Jamie.Blog
  alias Jamie.Blog.PostRevision
  alias Jamie.Repo
  alias Jamie.Support.BlogFixtures

  import Ecto.Query

  defp make_post(opts \\ []) do
    {:ok, post} = Blog.create_post(BlogFixtures.post_attrs(opts))
    post
  end

  defp revisions(post_id) do
    from(r in PostRevision, where: r.post_id == ^post_id, order_by: [asc: r.saved_at])
    |> Repo.all()
  end

  describe "save_revision/3" do
    test "first save is a snapshot" do
      post = make_post()

      assert {:ok, %PostRevision{is_snapshot: true, snapshot: snap, diff: nil}} =
               Blog.save_revision(nil, post.id, "first content")

      assert snap == "first content"
    end

    test "identical content is a no-op" do
      post = make_post()
      {:ok, _} = Blog.save_revision(nil, post.id, "same")

      assert :ok = Blog.save_revision(nil, post.id, "same")
      assert [%PostRevision{}] = revisions(post.id)
    end

    test "small edit after a snapshot stores a diff" do
      post = make_post()
      base = String.duplicate("the quick brown fox jumps over the lazy dog\n", 50)
      {:ok, _} = Blog.save_revision(nil, post.id, base)

      tweaked = String.replace(base, "lazy", "sleepy", global: false)

      assert {:ok, %PostRevision{is_snapshot: false, diff: diff, snapshot: nil}} =
               Blog.save_revision(nil, post.id, tweaked)

      assert is_binary(diff)
    end

    test "wholesale rewrite snapshots instead of diffing" do
      post = make_post()
      {:ok, _} = Blog.save_revision(nil, post.id, "short")

      assert {:ok, %PostRevision{is_snapshot: true}} =
               Blog.save_revision(nil, post.id, String.duplicate("x", 200))
    end

    test "every 50th revision is forced to be a snapshot" do
      post = make_post()
      base = String.duplicate("steady content line\n", 30)
      {:ok, _} = Blog.save_revision(nil, post.id, base)

      # 48 tiny edits — each should be a diff
      Enum.each(2..49, fn n ->
        {:ok, _} = Blog.save_revision(nil, post.id, base <> "edit #{n}\n")
      end)

      # the 50th — forced snapshot
      assert {:ok, %PostRevision{is_snapshot: true, revision_number: 50}} =
               Blog.save_revision(nil, post.id, base <> "edit 50\n")
    end

    test "revision_number is assigned by the trigger, monotonically per post" do
      post = make_post()
      {:ok, r1} = Blog.save_revision(nil, post.id, "a")
      {:ok, r2} = Blog.save_revision(nil, post.id, "b")
      {:ok, r3} = Blog.save_revision(nil, post.id, "c")

      assert [r1.revision_number, r2.revision_number, r3.revision_number] == [1, 2, 3]
    end
  end

  describe "reconstruct_content/2" do
    test "returns snapshot content directly" do
      post = make_post()
      {:ok, rev} = Blog.save_revision(nil, post.id, "snapshotted")
      assert Blog.reconstruct_content(nil, rev.id) == "snapshotted"
    end

    test "walks the diff chain back to a snapshot" do
      post = make_post()
      base = String.duplicate("line of mostly-equal text\n", 40)
      {:ok, _} = Blog.save_revision(nil, post.id, base)

      v2 = base <> "one\n"
      v3 = v2 <> "two\n"
      v4 = v3 <> "three\n"

      {:ok, _} = Blog.save_revision(nil, post.id, v2)
      {:ok, _} = Blog.save_revision(nil, post.id, v3)
      {:ok, rev4} = Blog.save_revision(nil, post.id, v4)

      # confirm we actually have at least one diff in the chain
      assert Enum.any?(revisions(post.id), &(&1.is_snapshot == false))

      assert Blog.reconstruct_content(nil, rev4.id) == v4
    end
  end

  describe "list_revisions/2" do
    test "orders by saved_at descending" do
      post = make_post()
      {:ok, r1} = Blog.save_revision(nil, post.id, "one")
      {:ok, r2} = Blog.save_revision(nil, post.id, "two")
      {:ok, r3} = Blog.save_revision(nil, post.id, "three")

      ids = Blog.list_revisions(nil, post.id) |> Enum.map(& &1.id)
      assert ids == [r3.id, r2.id, r1.id]
    end
  end

  describe "name_revision/3" do
    test "promotes a diff revision to a snapshot with reconstructed content" do
      post = make_post()
      base = String.duplicate("stable\n", 50)
      {:ok, _} = Blog.save_revision(nil, post.id, base)
      v2 = base <> "added\n"
      {:ok, diff_rev} = Blog.save_revision(nil, post.id, v2)
      refute diff_rev.is_snapshot

      assert {:ok, %PostRevision{is_snapshot: true, snapshot: ^v2, diff: nil, name: "v2"}} =
               Blog.name_revision(nil, diff_rev.id, "v2")
    end

    test "naming an existing snapshot just sets the name" do
      post = make_post()
      {:ok, snap} = Blog.save_revision(nil, post.id, "snap")
      assert snap.is_snapshot

      assert {:ok, %PostRevision{is_snapshot: true, snapshot: "snap", name: "release"}} =
               Blog.name_revision(nil, snap.id, "release")
    end
  end

  describe "update_post/3 optimistic locking" do
    test "writes succeed when updated_at matches" do
      post = make_post()
      assert {:ok, updated} = Blog.update_post(post, %{markdown: "new body"}, post.updated_at)
      assert updated.markdown == "new body"
    end

    test "returns :conflict when updated_at is stale" do
      post = make_post()
      {:ok, _winner} = Blog.update_post(post, %{markdown: "winner"}, post.updated_at)

      assert {:error, :conflict} =
               Blog.update_post(post, %{markdown: "loser"}, post.updated_at)

      assert Repo.get!(Jamie.Blog.Post, post.id).markdown == "winner"
    end

    test "a successful update inserts a revision in the same transaction" do
      post = make_post()
      assert revisions(post.id) == []

      {:ok, _} = Blog.update_post(post, %{markdown: "next body"}, post.updated_at)

      assert [%PostRevision{is_snapshot: true, snapshot: "next body"}] = revisions(post.id)
    end

    test "a conflicted update does not insert a revision" do
      post = make_post()
      {:ok, _} = Blog.update_post(post, %{markdown: "winner"}, post.updated_at)
      before_count = length(revisions(post.id))

      {:error, :conflict} = Blog.update_post(post, %{markdown: "loser"}, post.updated_at)

      assert length(revisions(post.id)) == before_count
    end
  end
end
