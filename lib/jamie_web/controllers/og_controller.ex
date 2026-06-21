defmodule JamieWeb.OgController do
  use JamieWeb, :controller

  @supported [
    "post"
  ]

  def image(conn, %{"thing" => thing, "id" => _id}) when thing not in @supported do
    conn
    |> put_status(:not_found)
    |> text("Not Found")
  end

  def image(conn, %{"thing" => thing, "id" => id}) do
    IO.inspect(thing)
    IO.inspect(id)
    #
    text(conn, "hello world")
  end
end
