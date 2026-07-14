defmodule Jamie.Service.Linkding do
  @moduledoc """
  A library for accessing my Linkding service
  """
  import Ecto.Query
  alias Jamie.Content.Bookmark
  alias Jamie.Repo
  alias Jamie.Service
  alias Jamie.Workers.SyncBookmarks

  @http Service.get!(:http)

  @doc """
  syncs the bookmarks. If no date is supplied the last created at date
  is used
  """
  def sync_bookmarks(last_synced_at \\ nil) do
    # we need added since
    added_since =
      if last_synced_at == nil do
        last_synced_at()
      else
        last_synced_at
      end

    # now call the worker
    %{"added_since" => added_since}
    |> SyncBookmarks.new()
    |> Oban.insert()
  end

  @doc """
  Returns the last synced at date in a format that works
  with the Linkding rest API. If there are no bookmarks
  it returns utc_now() value minus a decafe
  """
  def last_synced_at do
    Bookmark
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> select([b], b.inserted_at)
    |> Repo.one()
    |> case do
      nil ->
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(365 * -10, :day)
        |> NaiveDateTime.truncate(:second)

      inserted_at ->
        inserted_at
    end
    |> NaiveDateTime.to_iso8601()
  end

  @doc """
  Returns the URL for a results dictionary.
  """
  def url do
    Application.get_env(:jamie, :linkding)[:host] <> "/api/bookmarks/"
  end

  def url(%{"next" => url}), do: url

  @doc """
  Wrapper around /api/bookmarks
  https://linkding.link/api/#bookmarks
  """
  def bookmarks do
    config = Application.get_env(:jamie, :linkding)
    bookmarks(config[:host] <> "/api/bookmarks/")
  end

  def bookmarks(url, opts \\ []) do
    # get the config, service and new opts
    config = Application.get_env(:jamie, :linkding)
    {http, opts} = Keyword.pop(opts, :http, @http)

    # make params and drop any nil values
    params =
      opts
      |> Keyword.take([:limit, :offset, :order, :added_since])
      |> Enum.reject(fn {_, v} -> is_nil(v) end)

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
