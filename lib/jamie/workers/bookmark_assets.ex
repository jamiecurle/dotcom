defmodule Jamie.Workers.BookmarkAssets do
  @moduledoc """
  A dedicated worker to upload bookmark assets up to the storage backend
  """
  use Oban.Worker,
    queue: :bookmark_assets,
    max_attempts: 3

  alias Jamie.Service

  @http Service.get!(:http)
  # @storage Service.get!(:r2)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # default request opts
    request_opts =
      [
        method: :get,
        headers: [
          {"Authorization", "Token " <> Application.get_env(:jamie, :linkding)[:api_token]}
        ]
      ]

    # if we have a favicon, get it
    favicon_data =
      Map.get(args, "favicon_src")
      |> case do
        nil -> false
        url -> @http.request([url: url] ++ request_opts)
      end

    # same with preview
    preview_data =
      Map.get(args, "preview_src")
      |> case do
        nil -> nil
        url -> @http.request([url: url] ++ request_opts)
      end

    # IO.inspect(favicon_data)
    # IO.inspect(preview_data)
    :ok
  end
end
