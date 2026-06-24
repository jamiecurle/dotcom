defmodule Jamie.Workers.OgImageCreate do
  @moduledoc """
  Writes an opengraph image for a "thing" with a matching hash exists on R2.
  """
  use Oban.Worker,
    unique: [
      period: {20, :seconds},
      timestamp: :scheduled_at,
      keys: [:id],
      states: :incomplete,
      fields: [:args, :worker]
    ]

  require Logger
  alias Jamie.Opengraph

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"thing" => thing, "id" => id}}) do
    # get the create function
    create_fn =
      case thing do
        "post" -> &Opengraph.for_post/1
        _ -> fn _ -> {:error, :unknown_thing} end
      end

    # now do the create_fn
    case create_fn.(id) do
      {:ok, _result} ->
        Logger.info("Oban: success: og image create #{thing}:#{id}")
        :ok

      {:error, _reason} = error ->
        Logger.error("Oban: error: og image create #{thing}:#{id}")
        error
    end
  end
end
