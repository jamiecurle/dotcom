defmodule JamieWeb.Plugs.TrackPageview do
  @moduledoc """
  Records a pageview for successful HTML GET requests.

  Runs server-side (so it can't be blocked by ad-blockers and needs no
  client JS) and does all its work in a `before_send` callback that enqueues
  an Oban job — the response itself is never delayed by a database write.

  We derive the salted `visitor_hash` here, before enqueuing, so no IP
  address is ever handed to Oban or written to the database. Bots, non-HTML
  responses, and a handful of non-page routes (health checks, the admin and
  dev areas) are skipped.
  """
  @behaviour Plug

  import Plug.Conn

  alias Jamie.Analytics
  alias Jamie.Workers.PageviewTrack

  # Dynamic routes that go through the browser pipeline but aren't real
  # pageviews. (Static assets are served by Plug.Static before the router,
  # so they never reach this plug.)
  @skip_prefixes ["/office", "/dev", "/health", "/front-door"]

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%Plug.Conn{method: "GET"} = conn, _opts) do
    if skip_path?(conn.request_path) do
      conn
    else
      register_before_send(conn, &maybe_track/1)
    end
  end

  def call(conn, _opts), do: conn

  defp skip_path?(path), do: Enum.any?(@skip_prefixes, &String.starts_with?(path, &1))

  defp maybe_track(conn) do
    if trackable?(conn) do
      conn |> build_attrs() |> enqueue()
    end

    conn
  end

  # Only count 2xx responses that actually rendered HTML.
  defp trackable?(conn) do
    conn.status in 200..299 and html_response?(conn)
  end

  defp html_response?(conn) do
    conn
    |> get_resp_header("content-type")
    |> Enum.any?(&String.contains?(&1, "text/html"))
  end

  defp build_attrs(conn) do
    user_agent = conn |> get_req_header("user-agent") |> List.first()
    ua = Analytics.parse_user_agent(user_agent)

    %{
      path: conn.request_path,
      referrer_host: referrer_host(conn),
      browser: ua.browser,
      os: ua.os,
      device_type: ua.device_type,
      country: conn.assigns[:visitor_country],
      visitor_hash: Analytics.visitor_hash(client_ip(conn), user_agent)
    }
  end

  # Don't bother recording crawlers.
  defp enqueue(%{device_type: "bot"}), do: :ok

  defp enqueue(attrs) do
    attrs |> PageviewTrack.new() |> Oban.insert()
  end

  defp referrer_host(conn) do
    referer = conn |> get_req_header("referer") |> List.first()
    Analytics.referrer_host(referer, conn.host)
  end

  # Prefer the left-most X-Forwarded-For entry (the original client) when
  # we're behind a proxy; otherwise fall back to the socket peer.
  defp client_ip(conn) do
    case conn |> get_req_header("x-forwarded-for") |> List.first() do
      nil -> conn.remote_ip |> :inet.ntoa() |> to_string()
      forwarded -> forwarded |> String.split(",") |> List.first() |> String.trim()
    end
  end
end
