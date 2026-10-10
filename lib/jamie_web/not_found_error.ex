defmodule JamieWeb.NotFoundError do
  @moduledoc """
  Raised to answer with a plain 404 from anywhere, so a page that isn't
  open yet looks exactly like one that doesn't exist.
  """
  defexception message: "not found", plug_status: 404
end
