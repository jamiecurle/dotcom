defmodule Jamie.Workers.SyncBookmarksTest do
  alias Jamie.Content.Bookmark
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Workers.SyncBookmarks

  describe "worker" do
    setup do
      # Override the host for tests in this describe block
      linkding_config = Application.get_env(:jamie, :linkding, [])

      updated_config =
        Keyword.put(linkding_config, :host, "https://syncbookmarks.test.worker.describe")

      Application.put_env(:jamie, :linkding, updated_config)

      # now put things back as they were
      on_exit(fn ->
        Application.put_env(:jamie, :linkding, linkding_config)
      end)

      :ok
    end

    test "asdad" do
      # we have no bookmarks
      assert 0 == Repo.aggregate(Bookmark, :count)

      # run the job
      perform_job(SyncBookmarks, %{})

      # we have two
      assert 2 == Repo.aggregate(Bookmark, :count)
    end
  end
end
