defmodule Jamie.Workers.PostImageCleanupTest do
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  import ExUnit.CaptureLog

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Support.FakeR2
  alias Jamie.Workers.PostImageCleanup

  @used "11111111-1111-4111-8111-111111111111"
  @unused "22222222-2222-4222-8222-222222222222"
  @also_unused "33333333-3333-4333-8333-333333333333"

  defp days_ago(days), do: DateTime.add(DateTime.utc_now(), -days, :day)

  # an object uploaded `days` ago
  defp upload(key, days) do
    FakeR2.put_file("bytes", key)
    FakeR2.backdate(key, days_ago(days))
  end

  defp keys, do: FakeR2.list_objects() |> Enum.map(&elem(&1, 0))

  setup do
    {:ok, _post} =
      Content.create_post(
        ContentFixtures.post_attrs(
          markdown: "![](https://media.jamiecurle.com/posts/#{@used}.png)"
        )
      )

    upload("posts/#{@used}.png", 30)
    :ok
  end

  describe "deleting" do
    test "removes old unreferenced images and keeps everything else" do
      upload("posts/#{@unused}.png", 30)
      # unreferenced, but uploaded an hour ago - could be mid-edit
      upload("posts/#{@also_unused}.jpeg", 0)
      # not a post image shape, or not under posts/ at all
      upload("posts/not-a-uuid.png", 30)
      upload("opengraph/#{@unused}.png", 30)
      upload("bookmarks/1/favicon.png", 30)

      capture_log(fn -> assert :ok = perform_job(PostImageCleanup, %{"delete" => true}) end)

      assert Enum.sort(keys()) ==
               Enum.sort([
                 "posts/#{@used}.png",
                 "posts/#{@also_unused}.jpeg",
                 "posts/not-a-uuid.png",
                 "opengraph/#{@unused}.png",
                 "bookmarks/1/favicon.png"
               ])
    end

    test "deletes at most 50 per run, oldest first" do
      ids = for _ <- 1..60, do: Ecto.UUID.generate()
      ids |> Enum.with_index() |> Enum.each(fn {id, i} -> upload("posts/#{id}.png", 100 - i) end)

      capture_log(fn -> perform_job(PostImageCleanup, %{"delete" => true}) end)

      # the 50 oldest are gone, the 10 newest wait for the next run
      remaining = keys() -- ["posts/#{@used}.png"]

      assert Enum.sort(remaining) ==
               ids |> Enum.drop(50) |> Enum.map(&"posts/#{&1}.png") |> Enum.sort()
    end
  end

  describe "safety" do
    test "without delete nothing is removed" do
      upload("posts/#{@unused}.png", 30)

      capture_log(fn -> assert :ok = perform_job(PostImageCleanup, %{}) end)

      assert "posts/#{@unused}.png" in keys()
    end

    test "refuses to run when nothing is referenced" do
      Repo.delete_all(Jamie.Content.Post)
      upload("posts/#{@unused}.png", 30)

      capture_log(fn ->
        assert {:cancel, :no_references} = perform_job(PostImageCleanup, %{"delete" => true})
      end)

      assert "posts/#{@used}.png" in keys()
      assert "posts/#{@unused}.png" in keys()
    end

    test "is scheduled hourly as a dry run" do
      {Oban.Plugins.Cron, opts} =
        Application.get_env(:jamie, Oban)[:plugins] |> List.keyfind(Oban.Plugins.Cron, 0)

      assert {"0 * * * *", PostImageCleanup, args: %{"delete" => false}} in opts[:crontab]
    end
  end
end
