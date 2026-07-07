defmodule Jamie.Workers.SyncBookmarks do
  @moduledoc """
  Job to sync bookmarks Linkding
  """
  use Oban.Worker, queue: :bookmarks, max_attempts: 3

  @impl Oban.Worker
  def perform(%Oban.Job{args: _attrs}) do
    :ok
  end
end
