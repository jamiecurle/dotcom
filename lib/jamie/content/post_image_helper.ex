defmodule Jamie.Content.PostImageHelper do
  @moduledoc """
  Helpers for working with images in posts.
  """

  # The uploader names every post image posts/<uuid>.<ext>, so a UUID following
  # posts/ is a reference however it got into the text - markdown image, plain
  # link, raw <img>, or through the cdn-cgi resizer.
  @post_image_id ~r/posts\/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/i

  @doc """
  Returns the UUIDs of every post image referenced anywhere in `text`.

  Deliberately loose: anything that looks like a reference counts, because the
  cost of a false match is keeping an image and the cost of a miss is deleting
  one.
  """
  @spec post_image_ids(String.t() | nil) :: [String.t()]
  def post_image_ids(nil), do: []

  def post_image_ids(text) do
    @post_image_id
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.map(&String.downcase/1)
  end

  @doc """
  Takes the markdown from a post and returns a list of the images contained
  """
  @spec md_images(String.t()) :: [String.t()]
  def md_images(markdown) do
    # build the regex
    ~r/!\[.*?\]\(https:\/\/media\.jamiecurle\.com\/(?<path>.+)\)/
    |> Regex.scan(markdown, capture: :all_names)
    |> List.flatten()
  end
end
