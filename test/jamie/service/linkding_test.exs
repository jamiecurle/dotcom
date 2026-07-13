defmodule Jamie.Service.Linkding.Test do
  use Jamie.DataCase

  alias Jamie.Content
  alias Jamie.Repo
  alias Jamie.Service.Linkding
  alias Jamie.Support.ContentFixtures

  describe "url" do
    test "url/0 works with no arguments" do
      assert Linkding.url() == "https://your.linkding/api/bookmarks/"
    end

    test "url/1 returns next from results" do
      # note: the default fake_req.request functions return a total offset
      #       of three bookmarks over two pages. Page 1 has two, page 2 has one.
      #       there is no third page
      # get the first page
      results = Linkding.bookmarks()
      %{"next" => page_two_url} = results
      assert page_two_url == "https://your.linkding/api/bookmarks/?limit=2&offset=2"

      # get the second page
      results = Linkding.bookmarks(page_two_url)
      %{"next" => page_three_url} = results
      assert page_three_url == nil
    end
  end

  describe "last_synced_at/0" do
    test "returns a decade ago if no bookmarks" do
      assert 0 == Repo.aggregate(Content.Bookmark, :count)

      assert NaiveDateTime.utc_now()
             |> NaiveDateTime.add(365 * -10, :day)
             |> NaiveDateTime.truncate(:second)
             |> NaiveDateTime.to_iso8601() ==
               Linkding.last_synced_at()
    end

    test "returns the last synced date based on the bookmarks in db" do
      # make a bookmark
      ContentFixtures.bookmark_fixture(%{inserted_at: ~N[2026-01-01 00:00:00]})
      assert 1 == Repo.aggregate(Content.Bookmark, :count)
      assert "2026-01-01T00:00:00" == Linkding.last_synced_at()
    end
  end

  describe "sync_bookmarks" do
    setup do
      # Override the host for tests in this describe block
      linkding_config = Application.get_env(:jamie, :linkding, [])

      updated_config =
        Keyword.put(linkding_config, :host, "https://linkding.bookmarks-sync.describe")

      Application.put_env(:jamie, :linkding, updated_config)

      # now put things back as they were
      on_exit(fn ->
        Application.put_env(:jamie, :linkding, linkding_config)
      end)

      :ok
    end

    test "we supply a data" do
      # since has to
      Linkding.bookmarks(added_since: "2026-07-09T00:00:00")
      |> IO.inspect(label: "test")
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
      # this basically tests the FakeReq module more than anything
      # but it is useful as if this fails, it's quick to diagnose FakeReq
      assert Linkding.bookmarks() |> Map.keys() == ["count", "next", "previous", "results"]
    end
  end
end
