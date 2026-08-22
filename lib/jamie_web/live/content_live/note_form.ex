defmodule JamieWeb.ContentLive.NoteForm do
  use JamieWeb, :live_view
  alias Jamie.Content

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, show_preview: true, preview_version: 0)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope} full_bleed>
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
              phx-debounce="1500"
              required
            />

            <.input
              field={@form[:status]}
              type="select-naked"
              label="Status"
              options={Enum.map(Content.Note.statuses(), &{String.capitalize(to_string(&1)), &1})}
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

            <%!-- Per-note CSS, injected into the blank layout when the note is
                  rendered publicly. Optional: blank means the note just gets
                  the default notes.css. --%>
            <.input
              field={@form[:custom_css]}
              type="textarea-naked"
              label="Custom CSS"
              class="textarea w-full font-mono min-h-48"
              placeholder={~s(:root { --bg: #E1130F; --base: 32px; })}
              phx-debounce="1500"
            />

            <div class="mt-4 flex items-center gap-2">
              <button type="submit" class="btn btn-primary" phx-disable-with="Saving...">
                Save Note
              </button>
              <button
                :if={@live_action == :edit}
                type="button"
                class="btn btn-ghost btn-sm"
                phx-click="toggle-preview"
              >
                <.icon
                  name={if @show_preview, do: "hero-eye-slash", else: "hero-eye"}
                  class="size-4"
                />
                {if @show_preview, do: "Hide preview", else: "Show preview"}
              </button>
            </div>
          </.form>
        </div>

        <%!-- The public note page is a plain controller, not a LiveView, so it
              can't push its own updates. Bumping @preview_version changes the
              iframe src, which is what makes the browser refetch it -- see
              save_note/3. --%>
        <div :if={@live_action == :edit and @show_preview} class="preview-pane">
          <iframe
            id="note-preview"
            src={~p"/notes/#{@note.id}?v=#{@preview_version}"}
            title="Note preview"
          />
        </div>
      </div>
    </Layouts.office>
    """
  end

  @impl true
  def handle_event("toggle-preview", _params, socket) do
    {:noreply, update(socket, :show_preview, &(!&1))}
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
    case Content.create_note(note_params) do
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

    case Content.update_note(note, note_params) do
      {:ok, updated} ->
        {:noreply,
         socket
         |> assign(:note, updated)
         |> assign(:form, to_form(Content.change_note(updated)))
         |> update(:preview_version, &(&1 + 1))
         |> put_flash(:info, "note updated successfully.")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  defp apply_action(socket, :new, _params) do
    note = %Content.Note{}
    changeset = Content.change_note(note)

    socket
    |> assign(:page_title, "new note")
    |> assign(:note, note)
    |> assign(:form, to_form(changeset))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    note = Content.get_note!(id)
    changeset = Content.change_note(note)

    socket
    |> assign(:page_title, "Editing #{note.title}")
    |> assign(:note, note)
    |> assign(:form, to_form(changeset))
  end
end
