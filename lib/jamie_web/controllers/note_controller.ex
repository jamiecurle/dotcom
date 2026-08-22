defmodule JamieWeb.NoteController do
  use JamieWeb, :controller

  alias Jamie.Content

  def note(conn, %{"id" => id}) do
    note =
      Content.get_note!(id)

    conn
    |> put_root_layout(html: {JamieWeb.Layouts, :blank})
    |> assign(:note, note)
    |> render()
  end
end
