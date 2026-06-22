defmodule JamieWeb.OgController do
  use JamieWeb, :controller

  alias Jamie.Blog.Post
  alias Jamie.Repo

  @supported [
    "post"
  ]

  @schemas %{
    "post" => Post
  }

  @doc """

  """
  def image(conn, %{"thing" => thing, "id" => _id}) when thing not in @supported do
    conn
    |> put_status(:not_found)
    |> text("Not Found")
  end

  def image(conn, %{"thing" => thing, "id" => id}) do
    #
    @schemas
    |> Map.get(thing)
    |> Repo.get(id)
    |> case do
      nil ->
        conn
        |> put_status(:not_found)
        |> text("Not Found")

      db_thing ->
        host = Application.get_env(:jamie, :images)[:host]
        url = "https://" <> host <> "/opengraph/" <> db_thing.og_hash <> ".jpeg"

        conn
        |> redirect(external: url)
    end
  end
end
