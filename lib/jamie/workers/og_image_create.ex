defmodule Jamie.Workers.OgImageCreate do
  @moduledoc """
  Ensures an opengraph image with a matching hash exists on R2.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"og_hash" => _og_hash, "thing" => _thing, "id" => _id}}) do
    # does hash exist?
    #
    {:ok, :created}
  end
end
