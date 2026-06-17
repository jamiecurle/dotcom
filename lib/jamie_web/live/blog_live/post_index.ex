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
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <ul>
        <li :for={post <- @posts}>
          <.link href={~p"/office/posts/#{post.id}"}>{post.title}</.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
