defmodule Jamie.Workers.PageviewTrack do
  @moduledoc """
  Persists a single pageview off the request path.

  The caller (the tracking plug / LiveView hook) has already derived every
  attribute — including the salted `visitor_hash` — so that no raw IP address
  is ever passed through, or stored in, the Oban jobs table.
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Jamie.Analytics

  @impl Oban.Worker
  def perform(%Oban.Job{args: attrs}) do
    case Analytics.track(attrs) do
      {:ok, _pageview} -> :ok
      # A malformed pageview is not worth retrying — drop it.
      {:error, _changeset} -> {:cancel, :invalid_pageview}
    end
  end
end
