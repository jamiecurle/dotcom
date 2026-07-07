defmodule Jamie.Workers.SyncBookmarksTest do
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo
  alias Jamie.Workers.SyncBookmarks

  describe "works as expected" do
    test "asdad" do
      perform_job(SyncBookmarks, %{})
    end
  end
end
