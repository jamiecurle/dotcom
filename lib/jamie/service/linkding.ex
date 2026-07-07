defmodule Jamie.Service.Linkding do
  @moduledoc """
  A library for accessing my Linkding service
  """
  import Ecto.Query
  alias Jamie.Content.Bookmark
  alias Jamie.Repo

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
  def bookmarks(url \\ nil, opts \\ []) do
    # get the config
    config = Application.get_env(:jamie, :linkding)

    # make the params
    params = Keyword.take(opts, [:limit, :offset, :order, :url])

    # if url isn't in the params add it
    url =
      if url == nil do
        config[:host] <> "/api/bookmarks"
      else
        url
      end

    # now make the request
    {:ok, resp} =
      Req.get(url,
        headers: [{"Authorization", "Token #{config[:api_token]}"}],
        params: params
      )

    resp.body
  end
end
