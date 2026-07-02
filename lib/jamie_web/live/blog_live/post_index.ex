defmodule JamieWeb.BlogLive.PostIndex do
  use JamieWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      with posts <- Jamie.Blog.all_posts() do
        socket
        |> assign(:posts, posts)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6 flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Posts</h1>
        <.link navigate={~p"/office/posts/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New post
        </.link>
      </header>

      <ul class="menu w-full rounded-box bg-base-100 shadow-sm">
        <li :for={post <- @posts}>
          <.link navigate={~p"/office/posts/#{post.id}"}>{post.title}</.link>
        </li>
        <li :if={@posts == []} class="menu-disabled">
          <span>No posts yet.</span>
        </li>
      </ul>
    </Layouts.office>
    """
  end
end
