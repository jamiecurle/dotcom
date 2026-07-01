defmodule Jamie.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          slug: String.t() | nil,
          post_id: integer() | nil,
          post: Jamie.Blog.Post.t() | Ecto.Association.NotLoaded.t() | nil,
          note_id: integer() | nil,
          note: Jamie.Blog.Note.t() | Ecto.Association.NotLoaded.t() | nil
        }

  schema "tag_tags" do
    field :title, :string
    field :slug, :string
    belongs_to(:post, Jamie.Blog.Post)
    belongs_to(:note, Jamie.Blog.Note)
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:title])
    |> validate_required([:title])
    |> update_change(:title, &String.downcase/1)
    |> slugify()
    |> unique_constraint(:slug)
  end

  defp slugify(changeset) do
    case get_change(changeset, :title) do
      nil ->
        changeset

      title ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
