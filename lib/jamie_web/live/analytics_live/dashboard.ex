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

    assign(socket,
      total_pageviews: Analytics.total_pageviews(days),
      unique_visitors: Analytics.unique_visitors(days),
      series: Analytics.pageviews_over_time(days),
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
      <div class="max-w-5xl mx-auto p-4 space-y-6">
        <div class="flex items-center justify-between flex-wrap gap-2">
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
        </div>

        <div class="stats shadow w-full">
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

        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
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
    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title text-base">Pageviews over time</h2>
        <div :if={@series == []} class="text-sm opacity-60 py-8 text-center">
          No data for this window yet
        </div>
        <div :if={@series != []} class="flex items-end gap-1 h-40">
          <div
            :for={point <- @series}
            class="flex-1 bg-primary rounded-t tooltip"
            data-tip={"#{Calendar.strftime(point.day, "%b %d")}: #{point.views} views"}
            style={"height: #{bar_height(point.views, @max)}%"}
          >
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :title, :string, required: true
  attr :rows, :list, required: true
  attr :empty, :string, default: "No data yet"

  defp table_card(assigns) do
    ~H"""
    <div class="card bg-base-100 shadow">
      <div class="card-body">
        <h2 class="card-title text-base">{@title}</h2>
        <p :if={@rows == []} class="text-sm opacity-60">{@empty}</p>
        <table :if={@rows != []} class="table table-sm">
          <tbody>
            <tr :for={row <- @rows}>
              <td class="truncate max-w-[16rem]">{row.label}</td>
              <td class="text-right tabular-nums">{row.count}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end

  defp ranges, do: @ranges

  # Keep a sliver of height so even the quietest day is visible.
  defp bar_height(_views, 0), do: 0
  defp bar_height(views, max), do: max(round(views / max * 100), 2)
end
