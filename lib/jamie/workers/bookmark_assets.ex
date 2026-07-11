defmodule Jamie.Workers.BookmarkAssets do
  @moduledoc """
  A dedicated worker to upload bookmark assets up to the storage backend
  """
  use Oban.Worker,
    queue: :r2,
    max_attempts: 3

  alias Jamie.Service

  @http Service.get!(:http)
  @storage Service.get!(:r2)

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    # # default request opts
    # request_opts =
    #   [
    #     method: :get,
    #     headers: [
    #       {"Authorization", "Token " <> Application.get_env(:jamie, :linkding)[:api_token]}
    #     ]
    #   ]

    # get the data
    {favicon_data, _favicon_content_type} =
      Map.get(args, "favicon_src")
      |> case do
        nil -> {nil, nil}
        url -> iodata_and_content_type(url)
      end

    {preview_data, _favicon_content_type} =
      Map.get(args, "preview_src")
      |> case do
        nil -> {nil, nil}
        url -> iodata_and_content_type(url)
      end

    # and the destination
    favicon_dest = Map.get(args, "favicon_dest")
    preview_dest = Map.get(args, "preview_dest")

    # now the result
    favicon_result =
      case {favicon_data, favicon_dest} do
        {nil, nil} -> {:ok, :noop}
        {data, dest} -> @storage.put_file(data, dest)
      end

    preview_result =
      case {preview_data, preview_dest} do
        {nil, nil} -> {:ok, :noop}
        {data, dest} -> @storage.put_file(data, dest)
      end

    # as long as we're ok, then we return ok
    with {:ok, _} <- favicon_result,
         {:ok, _} <- preview_result do
      :ok
    end
  end

  def iodata_and_content_type(url) do
    # default request opts
    request_opts = [
      method: :get,
      headers: [
        {"Authorization", "Token " <> Application.get_env(:jamie, :linkding)[:api_token]}
      ]
    ]

    {:ok,
     %{
       headers: %{"content-type" => [content_type | _]},
       body: iodata
     }} = @http.request([url: url] ++ request_opts)

    {iodata, content_type}
  end
end
