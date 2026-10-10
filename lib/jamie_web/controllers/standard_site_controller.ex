defmodule JamieWeb.StandardSiteController do
  use JamieWeb, :controller

  @moduledoc """
  Proves to standard.site readers that this domain owns its publication
  record: the record says it's for this url, and this url answers with the
  record's `at://` uri. (Each post does the same for its document with a
  `<link rel="site.standard.document">` in its head.)
  """

  alias Jamie.Bluesky

  def publication(conn, _params) do
    case Bluesky.publication_uri(JamieWeb.Endpoint.url()) do
      {:ok, uri} ->
        conn
        |> put_resp_content_type("text/plain")
        |> send_resp(200, uri)

      # nothing published yet, or Bluesky is away: try again next time
      {:error, _} ->
        send_resp(conn, 404, "")
    end
  end
end
