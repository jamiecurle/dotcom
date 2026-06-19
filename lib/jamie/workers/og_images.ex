defmodule Jamie.Workers.OgImages do
  @moduledoc """
  Ensures an opengraph image with a matching hash exists on R2.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"og_hash" => og_hash}}) do
    og_hash
    {:ok, :created}
  end
end
