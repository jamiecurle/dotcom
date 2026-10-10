defmodule Jamie.Workers.PostImageCleanup do
  @moduledoc """
  Hourly job that removes post images from R2 that no post uses any more.

  Images are uploaded straight from the editor to posts/<uuid>.<ext> before the
  post is saved, so an image that gets edited back out of a post is left behind
  in the bucket. This finds those and deletes them.

  It errs heavily on the side of keeping things:

    * Only objects older than `@grace_hours` are considered, so an image that
      has just been uploaded but not saved into a post yet is never touched.
    * Only keys shaped exactly like posts/<uuid>.<ext> are considered - anything
      else under posts/ is left alone.
    * A reference anywhere in a post, note or pending suggestion keeps an image
      (see `Jamie.Content.referenced_post_image_ids/0`).
    * If nothing at all is referenced, the job refuses to run - that smells like
      the wrong database, not a blog with no images.
    * At most `@max_per_run` objects go per run, oldest first, so a bug can
      only do a bounded amount of damage before someone notices the logs.

  Pass `"delete" => true` in the args to actually delete. Without it the job
  only logs what it would have removed.
  """
  use Oban.Worker, queue: :r2, max_attempts: 3

  require Logger

  alias Jamie.Content
  alias Jamie.Service

  @storage Service.get!(:r2)

  @prefix "posts/"
  @grace_hours 24
  @max_per_run 50

  @post_image_key ~r/^posts\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})(\.[A-Za-z0-9]+)?$/i

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    delete? = Map.get(args, "delete", false) == true
    cutoff = DateTime.add(DateTime.utc_now(), -@grace_hours, :hour)
    referenced = Content.referenced_post_image_ids()

    if MapSet.size(referenced) == 0 do
      Logger.warning("post image cleanup: no referenced images found, refusing to run")
      {:cancel, :no_references}
    else
      referenced
      |> unused(cutoff)
      |> Enum.take(@max_per_run)
      |> remove(delete?)
    end
  end

  @doc """
  Keys under posts/ uploaded before `cutoff` whose UUID is not in `referenced`,
  oldest first.
  """
  def unused(referenced, cutoff) do
    @storage.list_objects_modified(@prefix)
    |> Enum.filter(fn {key, modified} ->
      DateTime.before?(modified, cutoff) and unreferenced?(key, referenced)
    end)
    |> Enum.sort_by(fn {_key, modified} -> modified end, DateTime)
    |> Enum.map(fn {key, _modified} -> key end)
  end

  # A key we don't recognise is never "unreferenced" - we leave it alone.
  defp unreferenced?(key, referenced) do
    case Regex.run(@post_image_key, key, capture: :all_but_first) do
      [id | _] -> not MapSet.member?(referenced, String.downcase(id))
      nil -> false
    end
  end

  defp remove([], _delete?), do: :ok

  defp remove(keys, false) do
    Enum.each(keys, &Logger.info("post image cleanup: would delete #{&1} (dry run)"))
    :ok
  end

  defp remove(keys, true) do
    # @max_per_run is well under the 1000-key cap on a single DeleteObjects call
    {:ok, _} = @storage.delete_files(keys)
    Enum.each(keys, &Logger.info("post image cleanup: deleted #{&1}"))
    :ok
  end
end
