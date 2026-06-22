defmodule Jamie.Workers.OgImageCreate do
  @moduledoc """
  Writes an opengraph image for a "thing" with a matching hash exists on R2.
  """
  use Oban.Worker, queue: :default, max_attempts: 5

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"thing" => thing, "id" => id}}) do
    # get the type of thing
    thing
    |> type()
    |> retreive(id)

    {:ok, :created}
  end

  defp type(thing) do
    case thing do
      "post" -> Jamie.Blog.Post
    end
  end

  defp retreive(schema, id) do
    Jamie.Repo.get!(schema, id)
  end
end
