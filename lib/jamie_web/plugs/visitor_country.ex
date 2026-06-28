defmodule JamieWeb.Plugs.VisitorCountry do
  @moduledoc """
  Captures the visitor's country (once per request) from Cloudflare's
  `CF-IPCountry` header.

  We stash the normalized code in two places so both pageview-tracking paths
  can reach it:

    * `conn.assigns[:visitor_country]` — read by the `TrackPageview` plug for
      the initial HTTP request.
    * the session — read by the `JamieWeb.Analytics.Tracker` LiveView hook for
      subsequent in-app navigations, which happen over the websocket where the
      `CF-IPCountry` header isn't available.

  No IP is involved: Cloudflare resolves the country at its edge and we only
  ever see the two-letter code.
  """
  @behaviour Plug

  import Plug.Conn

  alias Jamie.Analytics

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    country =
      conn
      |> get_req_header("cf-ipcountry")
      |> List.first()
      |> Analytics.normalize_country()

    conn
    |> assign(:visitor_country, country)
    |> put_session("visitor_country", country)
  end
end
