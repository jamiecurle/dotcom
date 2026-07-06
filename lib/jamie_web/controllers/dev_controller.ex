defmodule JamieWeb.DevController do
  @moduledoc """
  Development helpers
  """
  use JamieWeb, :controller
  alias Jamie.Content
  alias Jamie.Opengraph.Image

  @doc false
  def og_image(conn, %{"id" => id}) do
    post = Content.get_post!(id)
    image = Image.create(post.title, post.description, "/posts/#{post.slug}")

    conn
    |> put_resp_header("Content-Type", "image/png")
    |> send_resp(200, image)
  end
end
