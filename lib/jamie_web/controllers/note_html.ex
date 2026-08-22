defmodule JamieWeb.NoteHTML do
  @moduledoc """
  This module contains pages rendered by NoteController.

  See the `note_html` directory for all templates available.
  """
  use JamieWeb, :html

  embed_templates "note_html/*"
end
