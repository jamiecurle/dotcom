defmodule JamieWeb.AnalyticsLive.Dashboard do
  @moduledoc """
  Admin analytics dashboard: pageviews, unique visitors, top pages and
  referrers, and device/browser/OS breakdowns over a selectable window.

  Lives under `/office`, so it's already behind authentication. Data refreshes
  itself every 30s while the LiveView is connected.
  """
  use JamieWeb, :live_view

  alias Jamie.Analytics

  @ranges [{"7 days", 7}, {"30 days", 30}, {"90 days", 90}]
  @refresh_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Process.send_after(self(), :refresh, @refresh_ms)

    {:ok, socket |> assign(:days, 7) |> load()}
  end

  @impl true
  def handle_event("set_range", %{"days" => days}, socket) do
    {:noreply, socket |> assign(:days, String.to_integer(days)) |> load()}
  end

  @impl true
  def handle_info(:refresh, socket) do
    Process.send_after(self(), :refresh, @refresh_ms)
    {:noreply, load(socket)}
  end

  # Pull everything the dashboard needs for the current window in one place.
  defp load(socket) do
    days = socket.assigns.days

    socket
    |> assign(
      total_sessions: Analytics.total_sessions(days),
      total_pageviews: Analytics.total_pageviews(days),
      unique_visitors: Analytics.unique_visitors(days),
      series: fill_series(Analytics.pageviews_over_time(days), days),
      top_pages: Analytics.top_pages(days),
      top_referrers: Analytics.top_referrers(days),
      browsers: Analytics.breakdown_by(:browser, days),
      systems: Analytics.breakdown_by(:os, days),
      devices: Analytics.breakdown_by(:device_type, days)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <div class="flex flex-col gap-6">
        <header class="flex flex-wrap items-center justify-between gap-2">
          <h1 class="text-2xl font-semibold">Analytics</h1>
          <div class="join">
            <button
              :for={{label, days} <- ranges()}
              class={["btn btn-sm join-item", @days == days && "btn-primary"]}
              phx-click="set_range"
              phx-value-days={days}
            >
              {label}
            </button>
          </div>
        </header>

        <div class="stats stats-vertical w-full shadow-sm sm:stats-horizontal">
          <div class="stat">
            <div class="stat-title">Visits</div>
            <div class="stat-value">{@total_sessions}</div>
            <div class="stat-desc">last {@days} days</div>
          </div>
          <div class="stat">
            <div class="stat-title">Pageviews</div>
            <div class="stat-value">{@total_pageviews}</div>
            <div class="stat-desc">last {@days} days</div>
          </div>
          <div class="stat">
            <div class="stat-title">Unique visitors</div>
            <div class="stat-value">{@unique_visitors}</div>
            <div class="stat-desc">last {@days} days</div>
          </div>
        </div>

        <.chart series={@series} />

        <div class="grid gap-4 md:grid-cols-2">
          <.table_card title="Top pages" rows={@top_pages} />
          <.table_card title="Top referrers" rows={@top_referrers} empty="No external referrers yet" />
          <.table_card title="Browsers" rows={@browsers} />
          <.table_card title="Operating systems" rows={@systems} />
          <.table_card title="Devices" rows={@devices} />
        </div>
      </div>
    </Layouts.office>
    """
  end

  # A dependency-free bar chart: one bar per day, height proportional to the
  # busiest day in the window.
  attr :series, :list, required: true

  defp chart(assigns) do
    max = assigns.series |> Enum.map(& &1.views) |> Enum.max(fn -> 0 end)
    assigns = assign(assigns, :max, max)

    ~H"""
    <section class="card bg-base-100 shadow-sm">
      <div class="card-body">
        <h2 class="card-title text-base">Pageviews over time</h2>
        <p :if={@max == 0} class="text-sm text-base-content/60">No data for this window yet</p>
        <div :if={@max > 0} class="flex h-40 items-end gap-1">
          <div
            :for={point <- @series}
            class="flex-1 rounded-t bg-primary transition-opacity hover:opacity-70"
            title={"#{Calendar.strftime(point.day, "%b %d")}: #{point.views} views"}
            style={"height: #{bar_height(point.views, @max)}%"}
          >
          </div>
        </div>
      </div>
    </section>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :empty, :string, default: "No data yet"

  defp table_card(assigns) do
    ~H"""
    <section class="card bg-base-100 shadow-sm">
      <div class="card-body">
        <h2 class="card-title text-base">{@title}</h2>
        <p :if={@rows == []} class="text-sm text-base-content/60">{@empty}</p>
        <table :if={@rows != []} class="table table-sm">
          <tbody>
            <tr :for={row <- @rows}>
              <td class="max-w-xs truncate">{row.label}</td>
              <td class="text-right tabular-nums">{row.count}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </section>
    """
  end

  defp ranges, do: @ranges

  # The DB only returns days that had traffic. Expand that into one entry per
  # day across the whole window (missing days = 0) so the chart always has a
  # bar per day rather than a single block.
  defp fill_series(rows, days) do
    by_day = Map.new(rows, fn row -> {NaiveDateTime.to_date(row.day), row.views} end)
    today = Date.utc_today()

    for offset <- (days - 1)..0//-1 do
      date = Date.add(today, -offset)
      %{day: date, views: Map.get(by_day, date, 0)}
    end
  end

  # Keep a sliver of height so even the quietest day is visible.
  defp bar_height(_views, 0), do: 0
  defp bar_height(views, max), do: max(round(views / max * 100), 2)
end
