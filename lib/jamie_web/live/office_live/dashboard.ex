defmodule JamieWeb.OfficeLive.Dashboard do
  alias Jamie.Blog
  use JamieWeb, :live_view

  alias Jamie.Analytics

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <div class="analytics">
        <header class="analytics-head">
          <h1>Dashboard</h1>
        </header>
        <div class="analytics-stats">
          <div class="analytics-stat">
            <span class="analytics-stat-title">Posts</span>
            <span :for={post <- @posts} class="analytics-stat-desc">
              <.link href={~p"/office/posts/#{post.id}"}>
                {post.title}
              </.link>
            </span>
            <span class="analytics-stat-desc">
              <.link href={~p"/office/posts/new"}> new post</.link>
            </span>
          </div>
          <div class="analytics-stat">
            <span class="analytics-stat-title">Notes</span>
            <span :for={note <- @notes} class="analytics-stat-desc">
              <.link href={~p"/office/notes/#{note.id}"}>
                {note.title}
              </.link>
            </span>
            <span class="analytics-stat-desc">
              <.link href={~p"/office/notes/new"}> new note</.link>
            </span>
          </div>
          <div class="analytics-stat">
            <span class="analytics-stat-title">Projects</span>
            <span class="analytics-stat-value"></span>
            <span class="analytics-stat-desc"> new project</span>
          </div>
          <div class="analytics-stat">
            <span class="analytics-stat-title">Bookmarks</span>
            <span class="analytics-stat-value"></span>
            <span class="analytics-stat-desc"> bookmarks</span>
          </div>
          <div class="analytics-stat">
            <span class="analytics-stat-title">Visits</span>
            <span class="analytics-stat-value">{@total_sessions}</span>
            <span class="analytics-stat-desc">last {@days} days</span>
          </div>
          <div class="analytics-stat">
            <span class="analytics-stat-title">Unique visitors</span>
            <span class="analytics-stat-value">{@unique_visitors}</span>
            <span class="analytics-stat-desc">last {@days} days</span>
            <span class="analytics-stat-desc">
              <.link href={~p"/office/analytics"}> analytics</.link>
            </span>
          </div>
        </div>
      </div>
    </Layouts.office>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> dashboard_data()}
  end

  def dashboard_data(socket) do
    days = 7

    socket
    |> assign(
      days: days,
      posts: Blog.latest_published_posts(5),
      notes: [],
      total_sessions: Analytics.total_sessions(days),
      unique_visitors: Analytics.unique_visitors(days)
    )
  end
end
