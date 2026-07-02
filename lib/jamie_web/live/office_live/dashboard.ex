defmodule JamieWeb.OfficeLive.Dashboard do
  alias Jamie.Blog
  use JamieWeb, :live_view

  alias Jamie.Analytics

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6">
        <h1 class="text-2xl font-semibold">Dashboard</h1>
      </header>

      <div class="stats stats-vertical mb-8 w-full shadow-sm sm:stats-horizontal">
        <div class="stat">
          <div class="stat-title">Visits</div>
          <div class="stat-value">{@total_sessions}</div>
          <div class="stat-desc">last {@days} days</div>
        </div>
        <div class="stat">
          <div class="stat-title">Unique visitors</div>
          <div class="stat-value">{@unique_visitors}</div>
          <div class="stat-desc">
            <.link navigate={~p"/office/analytics"} class="link link-hover">
              View analytics
            </.link>
          </div>
        </div>
      </div>

      <div class="grid gap-4 sm:grid-cols-2">
        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Posts</h2>
              <.link navigate={~p"/office/posts/new"} class="btn btn-primary btn-xs">
                <.icon name="hero-plus" class="size-3.5" /> New
              </.link>
            </div>
            <ul class="menu w-full px-0">
              <li :for={post <- @posts}>
                <.link navigate={~p"/office/posts/#{post.id}"}>{post.title}</.link>
              </li>
              <li :if={@posts == []} class="menu-disabled"><span>No posts yet.</span></li>
            </ul>
          </div>
        </div>

        <div class="card bg-base-100 shadow-sm">
          <div class="card-body">
            <div class="flex items-center justify-between">
              <h2 class="card-title">Notes</h2>
              <.link navigate={~p"/office/notes/new"} class="btn btn-primary btn-xs">
                <.icon name="hero-plus" class="size-3.5" /> New
              </.link>
            </div>
            <ul class="menu w-full px-0">
              <li :for={note <- @notes}>
                <.link navigate={~p"/office/notes/#{note.id}"}>{note.title}</.link>
              </li>
              <li :if={@notes == []} class="menu-disabled"><span>No notes yet.</span></li>
            </ul>
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
