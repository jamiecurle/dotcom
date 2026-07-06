defmodule JamieWeb.ContentLive.NoteIndex do
  use JamieWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    socket =
      with notes <- Jamie.Content.get_published_notes(socket.assigns.current_scope) do
        socket
        |> assign(:notes, notes)
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <ul>
        <li :for={post <- @notes}>
          <.link href={~p"/office/notes/#{post.id}"}>{post.title}</.link>
        </li>
      </ul>
    </Layouts.app>
    """
  end
end
