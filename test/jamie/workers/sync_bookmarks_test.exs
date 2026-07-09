defmodule Jamie.Workers.SyncBookmarksTest do
  alias Jamie.Content.Bookmark
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Support.ContentFixtures
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
