defmodule JamieWeb.BlogLive.NoteForm do
  use JamieWeb, :live_view
  alias Jamie.Blog

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, _params) do
    note = %Blog.Note{}
    changeset = Blog.change_note(note)

    socket
    |> assign(:page_title, "new note")
    |> assign(:note, note)
    |> assign(:form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <div class="editor-pane">
        <.form
          for={@form}
          id="note-form"
          phx-change="validate"
          phx-debounce="1500"
          phx-submit="save"
          phx-hook="SaveShortcut"
        >
          <.input
            field={@form[:title]}
            label="Title"
            type="text-naked"
            placeholder="Note title"
            required
          />

          <.input
            field={@form[:status]}
            type="select-naked"
            label="Status"
            options={Enum.map(Blog.Note.statuses(), &{String.capitalize(to_string(&1)), &1})}
          />

          <.input
            field={@form[:markdown]}
            type="textarea-naked"
            label="Content (Markdown)"
            class="textarea w-full flex-1 font-mono min-h-96"
            placeholder="Write your post in markdown..."
            phx-hook="SignImageUrl"
            phx-debounce="1500"
          />

          <div class="mt-4">
            <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
              Save Post
            </button>
          </div>
        </.form>
      </div>
    </Layouts.office>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"note" => _note_params}, socket) do
    {:noreply, socket}
  end

  # defp save_note(socket, :new, note_params) do
  #   case Blog.create_note(note_params) do
  #     {:ok, note} ->
  #       {:noreply,
  #        socket
  #        |> put_flash(:info, "Note saved")}

  #     # |> push_
  #     %Ecto.Changeset{} = changeset ->
  #       socket
  #       |> put_flash(:error, "could not save note")
  #       |> assign(form: to_form(changeset))

  #       {:noreply, socket}
  #   end
  # end
end
