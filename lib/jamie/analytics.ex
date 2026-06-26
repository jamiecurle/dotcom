defmodule Jamie.Analytics do
  @moduledoc """
  Lightweight, privacy-respecting web analytics.

  We record one immutable row per pageview (`Jamie.Analytics.Pageview`)
  and aggregate on read for the dashboard. No cookies, no client-side
  tracker, and crucially no raw IP address is ever stored — visitors are
  identified only by a salted, daily-rotating one-way hash so we can count
  uniques without holding personal data.
  """
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

  @doc """
  Parse a user-agent string into `%{browser, os, device_type}`.

  `device_type` is one of "desktop", "mobile", "tablet", "bot" or "other".
  UAParser doesn't classify device type directly, so we derive it from the
  OS and device families.
  """
  def parse_user_agent(nil), do: %{browser: nil, os: nil, device_type: "other"}

  def parse_user_agent(user_agent) do
    ua = UAParser.parse(user_agent)

    %{
      browser: present(ua.family),
      os: present(ua.os && ua.os.family),
      device_type: device_type(ua)
    }
  end

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
