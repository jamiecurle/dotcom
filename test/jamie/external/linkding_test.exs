defmodule Jamie.External.Linkding.Test do
  use Jamie.DataCase

  alias Jamie.Content
  alias Jamie.External.Linkding
  alias Jamie.Repo
  alias Jamie.Support.ContentFixtures

  describe "last_synced_at/0" do
    test "returns nil if no bookmarks" do
      assert 0 == Repo.aggregate(Content.Bookmark, :count)
      assert nil == Linkding.last_synced_at()
    end

    test "returns the last synced date based on the bookmarks in db" do
      # make a bookmark
      ContentFixtures.bookmark_fixture(%{inserted_at: ~N[2026-01-01 00:00:00]})
      assert 1 == Repo.aggregate(Content.Bookmark, :count)
      assert ~U[2026-01-01 00:00:00Z] == Linkding.last_synced_at()
    end
  end

  describe "bookmarks" do
    setup do
      # Override the host for tests in this describe block
      linkding_config = Application.get_env(:jamie, :linkding, [])

      updated_config =
        Keyword.put(linkding_config, :host, "https://linkding.test.bookmarks.describe")

      Application.put_env(:jamie, :linkding, updated_config)

      # now put things back as they were
      on_exit(fn ->
        Application.put_env(:jamie, :linkding, linkding_config)
      end)

      :ok
    end

    test "happy path" do
      Linkding.bookmarks()
    end
  end
end
