defmodule JamieWeb.Analytics.Tracker do
  @moduledoc """
  LiveView `on_mount` hook that records in-app navigations as pageviews.

  The `TrackPageview` plug only sees the initial HTTP request (the dead
  render). Once the LiveView is connected, subsequent `live_patch` /
  `navigate` moves happen over the websocket and never touch the plug — this
  hook captures those.

  We deliberately skip the *first* `handle_params` after connecting: that
  represents the same pageview the plug already counted for the initial load.

  Like the plug, visitor identity is derived once at mount (from the websocket
  peer / forwarded headers) into a salted hash, so no IP is retained.
  """
  import Phoenix.LiveView, only: [attach_hook: 4, connected?: 1, get_connect_info: 2]
  import Phoenix.Component, only: [assign: 3]

  alias Jamie.Analytics
  alias Jamie.Workers.PageviewTrack

  def on_mount(:track_pageviews, _params, _session, socket) do
    if connected?(socket) do
      socket =
        socket
        |> assign(:analytics_visitor, visitor_attrs(socket))
        |> attach_hook(:track_pageview, :handle_params, &track_params/3)

      {:cont, socket}
    else
      {:cont, socket}
    end
  end

  # First params after connect == the load the plug already recorded; skip it.
  defp track_params(_params, uri, %{assigns: %{analytics_seen: true}} = socket) do
    enqueue(socket, URI.parse(uri).path)
    {:cont, socket}
  end

  defp track_params(_params, _uri, socket) do
    {:cont, assign(socket, :analytics_seen, true)}
  end

  defp enqueue(_socket, nil), do: :ok

  defp enqueue(%{assigns: %{analytics_visitor: %{device_type: "bot"}}}, _path), do: :ok

  defp enqueue(socket, path) do
    visitor = socket.assigns.analytics_visitor

    %{
      path: path,
      browser: visitor.browser,
      os: visitor.os,
      device_type: visitor.device_type,
      visitor_hash: visitor.visitor_hash
    }
    |> PageviewTrack.new()
    |> Oban.insert()
  end

  defp visitor_attrs(socket) do
    user_agent = get_connect_info(socket, :user_agent)
    ua = Analytics.parse_user_agent(user_agent)

    %{
      browser: ua.browser,
      os: ua.os,
      device_type: ua.device_type,
      visitor_hash: Analytics.visitor_hash(client_ip(socket), user_agent)
    }
  end

  defp client_ip(socket) do
    case forwarded_for(socket) do
      nil -> peer_ip(socket)
      ip -> ip
    end
  end

  defp forwarded_for(socket) do
    socket
    |> get_connect_info(:x_headers)
    |> List.wrap()
    |> Enum.find_value(fn
      {"x-forwarded-for", value} -> value |> String.split(",") |> List.first() |> String.trim()
      _ -> nil
    end)
  end

  defp peer_ip(socket) do
    case get_connect_info(socket, :peer_data) do
      %{address: address} -> address |> :inet.ntoa() |> to_string()
      _ -> "unknown"
    end
  end
end
