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

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <div class="editor-split">
        <div class="editor-pane">
          <.form
            for={@form}
            id="editor-form"
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
              placeholder="Write your note in markdown..."
              phx-hook="SignImageUrl"
              phx-debounce="1500"
            />

            <div class="mt-4">
              <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
                Save Note
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.office>
    """
  end

  @impl true
  def handle_event("validate", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("save", %{"note" => note_params}, socket) do
    save_note(socket, socket.assigns.live_action, note_params)
  end

  @impl true
  def handle_event("edit", %{"note" => note_params}, socket) do
    save_note(socket, socket.assigns.live_action, note_params)
  end

  defp save_note(socket, :new, note_params) do
    case Blog.create_note(note_params) do
      {:ok, note} ->
        {:noreply,
         socket
         |> put_flash(:info, "Note saved")
         |> push_navigate(to: ~p"/office/notes/#{note.id}")}

      %Ecto.Changeset{} = changeset ->
        {:noreply,
         socket
         |> put_flash(:error, "could not save note")
         |> assign(form: to_form(changeset))}
    end
  end

  defp save_note(socket, :edit, note_params) do
    note = socket.assigns.note

    case Blog.update_note(note, note_params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:note, updated)
         |> assign(:form, to_form(Blog.change_note(updated)))
         |> put_flash(:info, "note updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp apply_action(socket, :new, _params) do
    note = %Blog.Note{}
    changeset = Blog.change_note(note)

    socket
    |> assign(:page_title, "new note")
    |> assign(:note, note)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    note = Blog.get_note!(id)
    changeset = Blog.change_note(note)

    socket
    |> assign(:page_title, "Editing #{note.title}")
    |> assign(:note, note)
    |> assign(:form, to_form(changeset))
  end
end
