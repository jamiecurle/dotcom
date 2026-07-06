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
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6 flex items-center justify-between">
        <h1 class="text-2xl font-semibold">Notes</h1>
        <.link navigate={~p"/office/notes/new"} class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New note
        </.link>
      </header>

      <ul class="menu w-full rounded-box bg-base-100 shadow-sm">
        <li :for={note <- @notes}>
          <.link navigate={~p"/office/notes/#{note.id}"}>{note.title}</.link>
        </li>
        <li :if={@notes == []} class="menu-disabled">
          <span>No notes yet.</span>
        </li>
      </ul>
    </Layouts.office>
    """
  end
end
