defmodule JamieWeb.FeedController do
  use JamieWeb, :controller

  alias Jamie.Content

  def index(conn, _params) do
    posts = Content.published_posts()
    base_url = JamieWeb.Endpoint.url()
    # the feed is the same for everyone, so it only mentions the mailing
    # list once it's switched on for everyone
    xml = JamieWeb.FeedXML.render(posts, base_url, subscribe?: Jamie.MailingList.enabled?())

    conn
    |> put_resp_content_type("application/atom+xml")
    |> send_resp(200, xml)
  end
end
