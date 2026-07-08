defmodule Jamie.External.Linkding do
  @moduledoc """
  A library for accessing my Linkding service
  """
  import Ecto.Query
  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Service

  @http Service.get!(:http)

  @doc """
  Returns the last synced at date in a format that works
  with the Linkding rest API
  """
  def last_synced_at do
    Bookmark
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> select([b], b.inserted_at)
    |> Repo.one()
  end

  @doc """
  Wrapper around /api/bookmarks
  https://linkding.link/api/#bookmarks
  """
  def bookmarks do
    config = Application.get_env(:jamie, :linkding)
    bookmarks(config[:host] <> "/api/bookmarks/")
  end

  def bookmarks(url, opts \\ []) do
    # get the config, service, new opts and make params
    config = Application.get_env(:jamie, :linkding)
    {http, opts} = Keyword.pop(opts, :http, @http)
    params = Keyword.take(opts, [:limit, :offset, :order, :url])

    # if url wasn't given, make the url
    url =
      if url == nil do
        config[:host] <> "/api/bookmarks/"
      else
        url
      end

    # now make the request
    {:ok, resp} =
      [
        url: url,
        method: :get,
        headers: [{"Authorization", "Token " <> config[:api_token]}],
        params: params
      ]
      |> http.request()

    resp.body
  end
end
