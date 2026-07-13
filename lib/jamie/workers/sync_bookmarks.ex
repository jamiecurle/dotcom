defmodule Jamie.Workers.SyncBookmarks do
  @moduledoc """
  Job to sync bookmarks Linkding
  """
  use Oban.Worker, queue: :bookmarks, max_attempts: 3

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Service.Linkding
  alias Jamie.Workers.BookmarkAssets

  # TODO: use a last_synced_date
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # call bookmarks with optional url from args
    url =
      args
      |> Map.get(
        "url",
        Application.get_env(:jamie, :linkding)[:host] <> "/api/bookmarks/"
      )

    added_since = Map.get(args, "added_since")

    response =
      if url do
        Linkding.bookmarks(url)
      else
        Linkding.bookmarks(added_since)
      end

    %{
      "next" => next,
      "results" => results
    } = response

    # now
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # create bookmark structs
    structs =
      results
      |> Enum.map(fn result ->
        # we know the images paths ahead of time
        favicon_dest = "/bookmarks/#{result["id"]}/favicon.png"
        preview_dest = "/bookmarks/#{result["id"]}/preview.png"

        # fire off that image job
        %{
          "favicon_src" => result["favicon"],
          "favicon" => favicon_dest,
          "preview_src" => result["favicon"],
          "preview" => preview_dest
        }
        |> BookmarkAssets.new()
        |> Oban.insert()

        # now build the struct
        %{
          id: result["id"],
          url: result["url"],
          title: result["title"],
          description: result["description"],
          favicon: favicon_dest,
          preview: preview_dest,
          inserted_at: now,
          updated_at: now
        }
      end)

    Repo.transact(fn ->
      {records, _stuff} =
        Repo.insert_all(Bookmark, structs,
          on_conflict: {:replace_all_except, [:id, :inserted_at]},
          conflict_target: :url
        )

      {:ok, records}
    end)

    # If there's a next page, schedule another sync job
    if next do
      %{"url" => next}
      |> __MODULE__.new()
      |> Oban.insert!()
    end

    :ok
  end
end
