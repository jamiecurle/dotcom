defmodule Jamie.Service.Linkding.Test do
  use Jamie.DataCase

  alias Jamie.Content
  alias Jamie.Repo
  alias Jamie.Service.Linkding

  describe "last_synced_at/0" do
    test "returns nil if no bookmarks" do
      assert 0 == Repo.aggregate(Content.Bookmark, :count)
      assert nil == Linkding.last_synced_at()
    end
  end
end
