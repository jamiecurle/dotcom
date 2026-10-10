defmodule JamieWeb.OfficeLive.MailingList do
  @moduledoc """
  Deliverability at a glance: how mail is faring (bounce and complaint
  rates against the providers' limits), who's subscribed, and what Postmark
  has reported, live as webhooks arrive. `?subscriber=<id>` opens one
  subscriber's history.
  """
  use JamieWeb, :live_view

  alias Jamie.MailingList
  alias Jamie.MailingList.{Stats, Webhooks}

  @days 30

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: Webhooks.subscribe()
    {:ok, socket |> assign(:days, @days) |> load()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    selected = params["subscriber"] && MailingList.get_subscriber(params["subscriber"])

    {:noreply,
     socket
     |> assign(:selected, selected)
     |> assign(:timeline, if(selected, do: Stats.subscriber_events(selected), else: []))}
  end

  # a webhook landed: everything on the page may have moved
  @impl true
  def handle_info({:email_event, _event}, socket), do: {:noreply, load(socket)}

  defp load(socket) do
    assign(socket,
      enabled?: MailingList.enabled?(),
      summary: Stats.summary(@days),
      subscribers: Stats.subscribers(),
      daily: Stats.daily(@days),
      sends: Stats.sends(20),
      events: Stats.recent_events(50),
      people: Stats.list_subscribers(200)
    )
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6 flex flex-wrap items-center gap-3">
        <h1 class="text-2xl font-semibold">Mailing list</h1>
        <span
          id="mailing-list-gate"
          class={["badge", if(@enabled?, do: "badge-success", else: "badge-ghost")]}
        >
          {if @enabled?, do: "Live", else: "Hidden from visitors"}
        </span>
        <.link
          navigate={~p"/office/mailing-list/preview"}
          id="preview-emails-link"
          class="btn btn-ghost btn-sm ml-auto"
        >
          <.icon name="hero-envelope" class="size-4" /> Preview emails
        </.link>
      </header>

      <%!-- the two numbers that decide whether mail keeps arriving --%>
      <div
        id="mailing-list-health"
        class="stats stats-vertical mb-6 w-full shadow-sm lg:stats-horizontal"
      >
        <div class="stat">
          <div class="stat-title">Delivered</div>
          <div class="stat-value">{@summary.delivered}</div>
          <div class="stat-desc">last {@days} days</div>
        </div>
        <div class="stat" id="bounce-rate">
          <div class="stat-title">Bounce rate</div>
          <div class={["stat-value", health_text(@summary.bounce_health)]}>
            {percent(@summary.bounce_rate)}
          </div>
          <div class="stat-desc">
            {@summary.hard_bounces} hard · {@summary.soft_bounces} soft · warn 2%, bad 5%
          </div>
        </div>
        <div class="stat" id="complaint-rate">
          <div class="stat-title">Spam complaints</div>
          <div class={["stat-value", health_text(@summary.complaint_health)]}>
            {percent(@summary.complaint_rate)}
          </div>
          <div class="stat-desc">{@summary.complaints} in all · keep under 0.1%, never 0.3%</div>
        </div>
        <div class="stat">
          <div class="stat-title">Suppressed</div>
          <div class="stat-value">{@subscribers.suppressed}</div>
          <div class="stat-desc">addresses never to mail again</div>
        </div>
      </div>

      <div class="mb-6 grid gap-4 lg:grid-cols-3">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Subscribers</h2>
            <ul id="subscribers-by-status" class="flex flex-col gap-1">
              <li :for={status <- [:confirmed, :pending, :suspended]} class="flex justify-between">
                <span class="capitalize">{status}</span>
                <span class="font-mono">{Map.get(@subscribers.by_status, status, 0)}</span>
              </li>
            </ul>
          </div>
        </div>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">How often</h2>
            <ul id="subscribers-by-frequency" class="flex flex-col gap-1">
              <li :for={frequency <- MailingList.frequencies()} class="flex justify-between">
                <span class="capitalize">{frequency}</span>
                <span class="font-mono">{Map.get(@subscribers.by_frequency, frequency, 0)}</span>
              </li>
            </ul>
          </div>
        </div>
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <h2 class="card-title">Worlds</h2>
            <ul id="subscribers-by-world" class="flex flex-col gap-1">
              <li
                :for={world <- ["everything" | MailingList.worlds()]}
                id={"world-count-#{world}"}
                class="flex justify-between"
              >
                <span>{world}</span>
                <span class="font-mono">{@subscribers.by_world[world]}</span>
              </li>
            </ul>
          </div>
        </div>
      </div>

      <%!-- a bar per day: green delivered, amber soft, red hard and complaints --%>
      <div class="card mb-6 bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Last {@days} days</h2>
          <div id="daily" class="flex h-24 items-end gap-px">
            <div
              :for={day <- @daily}
              class="flex flex-1 flex-col-reverse"
              title={day_title(day)}
            >
              <div class="bg-success" style={"height: #{bar(day.delivered, @daily)}px"}></div>
              <div class="bg-warning" style={"height: #{bar(day.soft_bounces, @daily)}px"}></div>
              <div
                class="bg-error"
                style={"height: #{bar(day.hard_bounces + day.complaints, @daily)}px"}
              >
              </div>
            </div>
          </div>
        </div>
      </div>

      <div
        :if={@selected}
        id="subscriber-timeline"
        class="card mb-6 border border-primary bg-base-100 shadow-sm"
      >
        <div class="card-body">
          <div class="flex items-center justify-between">
            <h2 class="card-title">{@selected.email}</h2>
            <.link patch={~p"/office/mailing-list"} class="btn btn-ghost btn-sm">Close</.link>
          </div>
          <p class="text-sm text-base-content/70">
            {@selected.status} · {@selected.frequency} · {worlds(@selected)} · {@selected.soft_bounce_count} soft bounces in a row
          </p>
          <p id="consent-record" class="text-sm text-base-content/70">
            {consent(@selected)}
          </p>
          <.event_table id="timeline-events" events={@timeline} show_subscriber={false} />
        </div>
      </div>

      <%!-- each digest period: what went, what came back, matched by message id --%>
      <div class="card mb-6 bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Digests</h2>
          <div class="overflow-x-auto">
            <table id="digest-sends" class="table table-sm">
              <thead>
                <tr>
                  <th>Period</th>
                  <th>Sent</th>
                  <th>Delivered</th>
                  <th>Bounced</th>
                  <th>Complaints</th>
                  <th>Bounce rate</th>
                  <th>Complaint rate</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={send <- @sends} id={"digest-send-#{String.replace(send.period, ":", "-")}"}>
                  <td class="whitespace-nowrap">
                    {send.period}
                    <span class="text-xs text-base-content/60">
                      {Calendar.strftime(send.sent_at, "%-d %b %H:%M")}
                    </span>
                  </td>
                  <td class="font-mono">{send.sent}</td>
                  <td class="font-mono">{send.delivered}</td>
                  <td class="font-mono">{send.hard_bounces} hard · {send.soft_bounces} soft</td>
                  <td class="font-mono">{send.complaints}</td>
                  <td class={["font-mono", health_text(send.bounce_health)]}>
                    {percent(send.bounce_rate)}
                  </td>
                  <td class={["font-mono", health_text(send.complaint_health)]}>
                    {percent(send.complaint_rate)}
                  </td>
                </tr>
                <tr :if={@sends == []}>
                  <td colspan="7" class="text-base-content/60">No digests sent yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>

      <div class="card mb-6 bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Recent events</h2>
          <.event_table id="recent-events" events={@events} show_subscriber={true} />
        </div>
      </div>

      <div class="card bg-base-100 shadow-sm">
        <div class="card-body">
          <h2 class="card-title">Everyone</h2>
          <div class="overflow-x-auto">
            <table id="subscribers" class="table table-sm">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Status</th>
                  <th>How often</th>
                  <th>Worlds</th>
                  <th>Soft bounces</th>
                  <th>Since</th>
                </tr>
              </thead>
              <tbody>
                <tr :for={person <- @people} id={"subscriber-#{person.id}"} class="hover">
                  <td>
                    <.link patch={~p"/office/mailing-list?#{[subscriber: person.id]}"} class="link">
                      {person.email}
                    </.link>
                  </td>
                  <td>
                    <span class={["badge badge-sm badge-soft", status_badge(person.status)]}>
                      {person.status}
                    </span>
                  </td>
                  <td>{person.frequency}</td>
                  <td class="max-w-64 truncate">{worlds(person)}</td>
                  <td class="font-mono">{person.soft_bounce_count}</td>
                  <td>{Calendar.strftime(person.inserted_at, "%-d %b %Y")}</td>
                </tr>
                <tr :if={@people == []}>
                  <td colspan="6" class="text-base-content/60">Nobody yet.</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </div>
    </Layouts.office>
    """
  end

  attr :id, :string, required: true
  attr :events, :list, required: true
  attr :show_subscriber, :boolean, required: true

  defp event_table(assigns) do
    ~H"""
    <div class="overflow-x-auto">
      <table id={@id} class="table table-sm">
        <thead>
          <tr>
            <th>When</th>
            <th>What</th>
            <th>Done</th>
            <th>Stream</th>
            <th :if={@show_subscriber}>Subscriber</th>
            <th>Details</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={event <- @events} id={"#{@id}-#{event.id}"}>
            <td class="whitespace-nowrap">
              {Calendar.strftime(event.occurred_at, "%-d %b %H:%M")}
            </td>
            <td>
              <span class={["badge badge-sm badge-soft", kind_badge(event)]}>
                {event.type || event.record_type}
              </span>
            </td>
            <td>{event.action}</td>
            <td>{event.message_stream}</td>
            <td :if={@show_subscriber}>
              <.link
                :if={event.subscriber}
                patch={~p"/office/mailing-list?#{[subscriber: event.subscriber.id]}"}
                class="link"
              >
                {event.subscriber.email}
              </.link>
              <span :if={!event.subscriber} class="text-base-content/50">gone</span>
            </td>
            <td class="max-w-md truncate text-xs text-base-content/70">
              {event.payload["Details"] || event.payload["Description"]}
            </td>
          </tr>
          <tr :if={@events == []}>
            <td colspan="6" class="text-base-content/60">Nothing from Postmark yet.</td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end

  defp percent(nil), do: "–"
  defp percent(rate), do: :erlang.float_to_binary(rate * 100, decimals: 2) <> "%"

  defp health_text(:ok), do: "text-success"
  defp health_text(:warn), do: "text-warning"
  defp health_text(:bad), do: "text-error"

  defp status_badge(:confirmed), do: "badge-success"
  defp status_badge(:pending), do: "badge-ghost"
  defp status_badge(:suspended), do: "badge-warning"

  defp kind_badge(event) do
    case Stats.kind(event.record_type, event.type) do
      :delivered -> "badge-success"
      :soft_bounces -> "badge-warning"
      kind when kind in [:hard_bounces, :complaints] -> "badge-error"
      _ -> "badge-ghost"
    end
  end

  defp consent(%{consented_at: nil}), do: "No consent recorded"

  defp consent(%{consented_at: at, consent_notice_version: version}),
    do: "Consented #{Calendar.strftime(at, "%-d %b %Y %H:%M")} UTC · privacy notice #{version}"

  defp worlds(%{everything: true}), do: "everything"
  defp worlds(%{worlds: worlds}), do: Enum.join(worlds, ", ")

  # bars share one scale: the busiest day fills the 96px chart
  defp bar(0, _daily), do: 0

  defp bar(n, daily) do
    busiest =
      daily
      |> Enum.map(&(&1.delivered + &1.soft_bounces + &1.hard_bounces + &1.complaints))
      |> Enum.max()

    max(round(n / busiest * 96), 1)
  end

  defp day_title(day) do
    "#{Calendar.strftime(day.date, "%-d %b")}: #{day.delivered} delivered, " <>
      "#{day.soft_bounces} soft, #{day.hard_bounces} hard, #{day.complaints} complaints"
  end
end
