defmodule Jamie.Tags do
  @moduledoc """
  Context boundary for tags
  """

  alias Jamie.Blog

  alias Jamie.Blog.{
    Note,
    Post
  }

  alias Jamie.Repo
  alias Jamie.Tags.Tag

  @doc """
  Tags a Post or a Note.
  If the tag doesn't exist, it is created
  """

  @spec tag(Post.t() | Note.t(), String.t()) :: {:ok | :error, any()}
  def tag(target, tag)

  def tag(%Blog.Note{} = note, tag) do
    Ecto.build_assoc(note, :tags)
    |> changeset_tag(%{title: tag})
    |> upsert_tag()
  end

  def tag(%Blog.Post{} = post, tag) do
    tag
    |> changeset_tag(%{title: tag})
    |> Ecto.Changeset.put_assoc(:tags)
    |> upsert_tag()
  end

  @doc """
  Gets a tag by title
  """
  def tag_by_title(title) do
    case Repo.get_by(Tag, title: title |> String.downcase()) do
      nil -> {:error, :not_found}
      %Tag{} = tag -> {:ok, tag}
    end
  end

  @doc """
  Inserts a tag, or returns the existing row if the slug already exists.
  """
  def upsert_tag(%Ecto.Changeset{} = changeset) do
    changeset
    |> Repo.insert(
      on_conflict: :nothing,
      conflict_target: :slug,
      returning: true
    )
  end

  @doc """
  Create a tag
  """
  def create_tag(attrs) do
    case changeset_tag(%Tag{}, attrs) do
      %{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> changeset
    end
  end

  @doc """
  Creates a changeset for a tag
  """
  def changeset_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end
end
