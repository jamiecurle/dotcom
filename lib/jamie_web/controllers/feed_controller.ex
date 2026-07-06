defmodule JamieWeb.FeedController do
  use JamieWeb, :controller

  alias Jamie.Content

  def index(conn, _params) do
    posts = Content.published_posts()
    base_url = JamieWeb.Endpoint.url()
    xml = JamieWeb.FeedXML.render(posts, base_url)

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, xml)
  end
end
