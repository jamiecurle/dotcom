defmodule Jamie.Tags do
  @moduledoc """
  Context boundary for tags
  """

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
  def tag(target, tag_title)

  def tag(%Post{} = post, tag_title) do
    with attrs <- %{title: tag_title},
         tag_cs <- changeset_tag(%Tag{}, attrs),
         {:ok, tag} <- upsert_tag(tag_cs) do
      # tag it
      tag_content(post, tag.id)
    end
  end

  def tag(%Note{} = note, tag_title) do
    with attrs <- %{title: tag_title},
         tag_cs <- changeset_tag(%Tag{}, attrs),
         {:ok, tag} <- upsert_tag(tag_cs) do
      # tag it
      tag_content(note, tag.id)
    end
  end

  defp tag_content(%Post{} = post, tag_id) do
    Repo.insert_all(
      "tags_posts",
      [%{post_id: post.id, tag_id: tag_id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(post, :tags, force: true)}
  end

  defp tag_content(%Note{} = note, tag_id) do
    Repo.insert_all(
      "tags_notes",
      [%{note_id: note.id, tag_id: tag_id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(note, :tags)}
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
      on_conflict: {:replace, [:slug]},
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
