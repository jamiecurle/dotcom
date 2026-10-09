defmodule JamieWeb.Plugs.TailnetOnly do
  @moduledoc """
  Keeps a route off the public internet by only answering requests made to
  the Tailscale hostname (`config :jamie, :mcp_host`).

  Public traffic arrives through the Cloudflare tunnel with the public
  hostname *and* a `cf-ray` header that Cloudflare always adds, so either
  check alone is enough to turn it away; both together give some defence in
  depth. Anything that fails gets a plain 404 so the route doesn't advertise
  that it exists. With no host configured the route is switched off.
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    allowed_host = Application.get_env(:jamie, :mcp_host)

    if allowed_host && conn.host == allowed_host && get_req_header(conn, "cf-ray") == [] do
      conn
    else
      conn |> send_resp(404, "Not Found") |> halt()
    end
  end
end
