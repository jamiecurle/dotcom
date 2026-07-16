defmodule Jamie.Workers.SyncBookmarks do
  @moduledoc """
  Job to sync bookmarks Linkding
  """
  use Oban.Worker, queue: :bookmarks, max_attempts: 3

  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Service.Linkding
  alias Jamie.Tags
  alias Jamie.Workers.BookmarkAssets

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # call bookmarks with optional url from args
    url =
      args
      |> Map.get(
        "url",
        Application.get_env(:jamie, :linkding)[:host] <> "/api/bookmarks/"
      )

    added_since =
      if Map.get(args, "added_since") == nil do
        Linkding.last_synced_at()
      else
        Map.get(args, "added_since")
      end

    response =
      if added_since do
        Linkding.bookmarks(url, added_since: added_since)
      else
        Linkding.bookmarks(url)
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
        # favicon is always a png
        favicon_dest =
          if result["favicon_url"] do
            "/bookmarks/#{result["id"]}/favicon.png"
          else
            nil
          end

        # preview could be any image type
        preview_dest =
          if result["preview_image_url"] do
            preview_ext = Path.extname(result["preview_image_url"])
            "/bookmarks/#{result["id"]}/preview#{preview_ext}"
          else
            nil
          end

        # fire off that image job if favicon_dest or preview_dest are a thing
        %{
          "favicon_src" => result["favicon_url"],
          "favicon_dest" => favicon_dest,
          "preview_src" => result["preview_image_url"],
          "preview_dest" => preview_dest
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

    # insert the bookmarks and their tags in one transaction so a bookmark
    # and its tags always land together
    Repo.transact(fn ->
      {totals, bookmarks} =
        Repo.insert_all(Bookmark, structs,
          on_conflict: {:replace_all_except, [:id, :inserted_at]},
          conflict_target: :url,
          returning: [:id, :url]
        )

      # a bookmark that already existed under a different id keeps that id,
      # so map tags by the real stored id (via url) not the incoming id
      url_to_id = Map.new(bookmarks, &{&1.url, &1.id})
      Tags.tag_bookmarks_bulk(results, url_to_id)

      {:ok, totals}
    end)

    # If there's a next page, schedule another sync job
    if next do
      %{"url" => next, "added_since" => added_since}
      |> __MODULE__.new()
      |> Oban.insert!()
    end

    :ok
  end
end
