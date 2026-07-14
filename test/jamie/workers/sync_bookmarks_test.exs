defmodule Jamie.Workers.SyncBookmarksTest do
  alias Jamie.Content.Bookmark
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Service.Linkding
  alias Jamie.Support.ContentFixtures
  alias Jamie.Workers.SyncBookmarks

  describe "sync_bookmarks" do
    setup do
      # Override the host for tests in this describe block
      linkding_config = Application.get_env(:jamie, :linkding, [])

      updated_config =
        Keyword.put(linkding_config, :host, "https://sync-bookmarks.describe")

      Application.put_env(:jamie, :linkding, updated_config)

      # now put things back as they were
      on_exit(fn ->
        Application.put_env(:jamie, :linkding, linkding_config)
      end)

      :ok
    end

    test "sync_bookmarks with no args populates once, then does incremental" do
      # no bookmarks
      assert 0 == Repo.aggregate(Bookmark, :count)

      # build the args and get page one
      args = %{added_since: Linkding.last_synced_at()}
      perform_job(Jamie.Workers.SyncBookmarks, args)

      # two bookmarks, one more sync job and two asset jobs
      assert 2 == Repo.aggregate(Bookmark, :count)
      assert 1 == all_enqueued(worker: Jamie.Workers.SyncBookmarks) |> length()
      assert 2 == all_enqueued(worker: Jamie.Workers.BookmarkAssets) |> length()

      # get the second page args before we drain the queue
      [page_2] = all_enqueued(worker: Jamie.Workers.SyncBookmarks)

      # this is 100% page 2
      assert page_2.args["url"] ==
               "https://sync-bookmarks.describe/api/bookmarks/?limit=2&offset=2"

      # one sync job and two asset jobs
      assert 1 == all_enqueued(worker: Jamie.Workers.SyncBookmarks) |> length()
      assert 2 == all_enqueued(worker: Jamie.Workers.BookmarkAssets) |> length()

      # drain the queue and we have 4 bookmarks, one more job and two asset jobs
      Oban.drain_queue(queue: :bookmarks)
      Oban.drain_queue(queue: :r2)
      assert 4 == Repo.aggregate(Bookmark, :count)

      # get page 3 and assert this is page 3
      [page_3] = all_enqueued(worker: Jamie.Workers.SyncBookmarks)

      assert page_3.args["url"] ==
               "https://sync-bookmarks.describe/api/bookmarks/?limit=2&offset=4"

      # process page 3 - last page
      Oban.drain_queue(queue: :bookmarks)
      Oban.drain_queue(queue: :r2)
      assert 5 == Repo.aggregate(Bookmark, :count)
      assert 0 == all_enqueued(worker: Jamie.Workers.SyncBookmarks) |> length()
      assert 0 == all_enqueued(worker: Jamie.Workers.BookmarkAssets) |> length()
    end

    test "syncbook_marks tags correctly" do
      # todo - more than just tagging things, needs the tag
      #        infra settingt up as for notes and posts
    end
  end

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

    test "happy path" do
      # we have no bookmarks
      assert 0 == Repo.aggregate(Bookmark, :count)

      # first job makes a second job
      perform_job(SyncBookmarks, %{})

      # get the second job
      [job] = all_enqueued(worker: "Jamie.Workers.SyncBookmarks")

      perform_job(SyncBookmarks, job.args)

      # assert length(jobs) == 3

      # we have three
      assert 3 == Repo.aggregate(Bookmark, :count)
    end

    test "idempotency" do
      # make a bookmark
      ContentFixtures.bookmark_fixture(%{
        url: "https://bradleywoolf.com/links-1/sequencing-my-own-dna-at-home"
      })

      # we have a bookmark
      assert 1 == Repo.aggregate(Bookmark, :count)

      # run the job
      perform_job(SyncBookmarks, %{})

      # and now we have two becasue the upsert worked
      assert 2 == Repo.aggregate(Bookmark, :count)
    end
  end
end
