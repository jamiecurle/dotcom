defmodule Jamie.Workers.SyncBookmarks do
  @moduledoc """
  Job to sync bookmarks Linkding
  """
  use Oban.Worker, queue: :bookmarks, max_attempts: 3

  alias Jamie.Content.Bookmark
  alias Jamie.External.Linkding
  alias Jamie.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: _args}) do
    # call bookmarks
    %{
      "next" => _next,
      "results" => results
    } = Linkding.bookmarks()

    # now
    now =
      DateTime.utc_now()
      |> DateTime.truncate(:second)

    # reminder: upload favicon and preview into cloudflare - serve those

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
        Repo.insert_all(Bookmark, structs)

      {:ok, records}
    end)

    :ok
  end
end
