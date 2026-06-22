defmodule Jamie.Opengraph do
  @moduledoc """
  Context boundary for opengraph specific things
  """
  alias Jamie.Opengraph.Image

  defdelegate for_post(post), to: Image
end
