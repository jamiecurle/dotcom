defmodule Jamie.Analytics do
  @moduledoc """
  Lightweight, privacy-respecting web analytics.

  We record one immutable row per pageview (`Jamie.Analytics.Pageview`) and
  aggregate on read for the dashboard. The headline metric is *visits*
  (sessions): a run of pageviews by the same visitor with no gap longer than
  60 minutes counts as one visit, so refreshing or clicking around doesn't
  inflate the number, but coming back later does. We
  derive sessions on read with a window function rather than tracking session
  state — see `total_sessions/1`.

  No cookies, no client-side tracker, and no raw IP is ever stored. Visitors
  are identified by a salted, daily-rotating one-way hash, which is stable far
  longer than a session needs yet can't link anyone across days.
  """
  # Pageviews from the same visitor more than this many minutes apart start a
  # new session/visit (GA's default is 30; we use 60).
  @session_timeout_minutes 60
  import Ecto.Query

  alias Jamie.Analytics.Pageview
  alias Jamie.Repo

  @doc """
  Insert a pageview. Expects a map of attributes already derived from the
  request (see `JamieWeb.Plugs.TrackPageview` and the Oban worker).
  """
  def track(attrs) do
    %Pageview{}
    |> Pageview.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Derive a stable-per-day visitor identifier from the IP and user-agent.

  The salt rotates every day (it folds in today's date and the app's
  `secret_key_base`), so the same visitor hashes consistently within a
  single day but cannot be tracked across days, and the hash cannot be
  reversed back to an IP.
  """
  def visitor_hash(ip, user_agent, date \\ Date.utc_today()) do
    salt = daily_salt(date)

    :crypto.hash(:sha256, [to_string(ip), "|", to_string(user_agent), "|", salt])
    |> Base.encode16(case: :lower)
  end

  defp daily_salt(date) do
    secret = Application.get_env(:jamie, JamieWeb.Endpoint)[:secret_key_base] || "dev-salt"
    secret <> Date.to_iso8601(date)
  end

  # Non-browser clients and crawlers that UAParser doesn't already flag as a
  # spider. Catches the HTTP libraries and scanners that hammer a fresh public
  # IP (Go-http-client, curl, python-requests, …) so they don't pollute stats.
  # Note: this can't catch scanners that spoof a real browser UA — that's a job
  # for the network edge (rate-limiting / Cloudflare), not analytics.
  @bot_ua_pattern ~r/bot|crawl|spider|slurp|go-http-client|http[-_]?client|python[-_]?requests|curl|wget|libwww|okhttp|axios|node[-_]?fetch|scrapy|httpx|aiohttp|postman|headless|phantomjs|zgrab|masscan|nuclei|nmap|semrush|ahrefs|\bjava\b/i

  @doc """
  Parse a user-agent string into `%{browser, os, device_type}`.

  `device_type` is one of "desktop", "mobile", "tablet", "bot" or "other".
  A missing user-agent, or one matching a known non-browser/crawler, is
  classified as "bot" (the tracking plug skips those). Otherwise UAParser's
  device/OS families decide desktop vs mobile vs tablet.
  """
  def parse_user_agent(user_agent) when user_agent in [nil, ""] do
    %{browser: nil, os: nil, device_type: "bot"}
  end

  def parse_user_agent(user_agent) do
    ua = UAParser.parse(user_agent)

    %{
      browser: present(ua.family),
      os: present(ua.os && ua.os.family),
      device_type: if(bot_ua?(user_agent), do: "bot", else: device_type(ua))
    }
  end

  defp bot_ua?(user_agent), do: Regex.match?(@bot_ua_pattern, user_agent)

  # UAParser reports spiders/crawlers with a "Spider" device family or brand.
  defp device_type(%{device: %{family: "Spider"}}), do: "bot"
  defp device_type(%{device: %{brand: "Spider"}}), do: "bot"
  defp device_type(%{family: nil}), do: "other"

  defp device_type(ua) do
    cond do
      tablet?(ua) -> "tablet"
      mobile?(ua) -> "mobile"
      true -> "desktop"
    end
  end

  defp tablet?(ua) do
    brand = ua.device && ua.device.brand

    (ua.device && ua.device.family) == "iPad" or
      (is_binary(brand) and String.contains?(brand, "Tablet"))
  end

  defp mobile?(ua) do
    (ua.os && ua.os.family) in ["iOS", "Android"] or ua.family == "Mobile Safari"
  end

  @doc """
  Extract the bare host of a referrer, dropping referrals from our own host
  (self-referrals aren't interesting) and anything that isn't a real URL.
  """
  def referrer_host(nil, _our_host), do: nil
  def referrer_host("", _our_host), do: nil

  def referrer_host(referer, our_host) do
    case URI.parse(referer) do
      %URI{host: host} when is_binary(host) and host != "" ->
        if host == our_host, do: nil, else: host

      _ ->
        nil
    end
  end

  defp present(nil), do: nil
  defp present(""), do: nil
  defp present("Other"), do: nil
  defp present(value), do: value

  ## Aggregate queries (all scoped to the last `days` days)

  defp since(days), do: DateTime.add(DateTime.utc_now(), -days, :day)

  @doc "Total pageviews in the window."
  def total_pageviews(days) do
    from(p in Pageview, where: p.inserted_at >= ^since(days), select: count(p.id))
    |> Repo.one()
  end

  @doc "Distinct visitor hashes in the window."
  def unique_visitors(days) do
    from(p in Pageview,
      where: p.inserted_at >= ^since(days),
      select: count(p.visitor_hash, :distinct)
    )
    |> Repo.one()
  end

  @doc """
  Total visits (sessions) in the window.

  Walking each visitor's pageviews in time order, a new session begins on their
  first hit and again after any gap longer than the session timeout. Counting
  those session-starts gives the number of visits.
  """
  def total_sessions(days) do
    # For each pageview, look up that visitor's previous pageview time.
    with_prev =
      from(p in Pageview,
        where: p.inserted_at >= ^since(days),
        windows: [visitor: [partition_by: p.visitor_hash, order_by: p.inserted_at]],
        select: %{
          inserted_at: p.inserted_at,
          prev_at: over(fragment("lag(?)", p.inserted_at), :visitor)
        }
      )

    # A session starts where there's no previous hit, or the gap exceeds the
    # timeout. Count those starts.
    from(row in subquery(with_prev),
      where:
        is_nil(row.prev_at) or
          row.inserted_at > datetime_add(row.prev_at, ^@session_timeout_minutes, "minute"),
      select: count()
    )
    |> Repo.one()
  end

  @doc "Pageviews and uniques grouped by calendar day, oldest first."
  def pageviews_over_time(days) do
    from(p in Pageview,
      where: p.inserted_at >= ^since(days),
      group_by: fragment("date_trunc('day', ?)", p.inserted_at),
      order_by: fragment("date_trunc('day', ?)", p.inserted_at),
      select: %{
        day: fragment("date_trunc('day', ?)", p.inserted_at),
        views: count(p.id),
        visitors: count(p.visitor_hash, :distinct)
      }
    )
    |> Repo.all()
  end

  @doc "Top paths by pageviews."
  def top_pages(days, limit \\ 10) do
    grouped_counts(:path, days, limit)
  end

  @doc "Top external referrer hosts by pageviews."
  def top_referrers(days, limit \\ 10) do
    from(p in Pageview,
      where: p.inserted_at >= ^since(days) and not is_nil(p.referrer_host),
      group_by: p.referrer_host,
      order_by: [desc: count(p.id)],
      limit: ^limit,
      select: %{label: p.referrer_host, count: count(p.id)}
    )
    |> Repo.all()
  end

  @doc """
  Breakdown of pageviews by a dimension column — one of
  `:browser`, `:os`, `:device_type` or `:country`.
  """
  def breakdown_by(dimension, days, limit \\ 10)
      when dimension in [:browser, :os, :device_type, :country] do
    grouped_counts(dimension, days, limit)
  end

  defp grouped_counts(field, days, limit) do
    from(p in Pageview,
      where: p.inserted_at >= ^since(days) and not is_nil(field(p, ^field)),
      group_by: field(p, ^field),
      order_by: [desc: count(p.id)],
      limit: ^limit,
      select: %{label: field(p, ^field), count: count(p.id)}
    )
    |> Repo.all()
  end
end
