defmodule Jamie.Workers.SyncBookmarks do
  @moduledoc """
  Job to sync bookmarks Linkding
  """
  use Oban.Worker, queue: :bookmarks, max_attempts: 3

  alias Jamie.Content.Bookmark
  alias Jamie.External.Linkding
  alias Jamie.Repo

  # TODO: upload favicon and preview into cloudflare and use CF urls not my home network
  # TODO: use a last_synced_date
  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # call bookmarks with optional url from args
    url = Map.get(args, "url")

    response =
      if url do
        Linkding.bookmarks(url)
      else
        Linkding.bookmarks()
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
        %{
          url: result["url"],
          title: result["title"],
          description: result["description"],
          favicon: result["favicon"],
          preview: result["preview_image_url"],
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
