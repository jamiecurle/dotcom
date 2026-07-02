defmodule Jamie.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jamie.Blog.{
    Post,
    Note
  }

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          slug: String.t() | nil
        }

  schema "tag_tags" do
    field :title, :string
    field :slug, :string
    many_to_many :posts, Post, join_through: "tags_posts"
    many_to_many :notes, Note, join_through: "tags_notes"
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
