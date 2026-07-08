defmodule Jamie.Workers.SyncBookmarksTest do
  alias Jamie.Content.Bookmark
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Workers.SyncBookmarks

  describe "works as expected" do
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
