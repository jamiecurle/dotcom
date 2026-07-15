defmodule Jamie.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jamie.Content.{
    Note,
    Post
  }

  @type t :: %__MODULE__{
          id: integer() | nil,
          title: String.t() | nil,
          slug: String.t() | nil
        }

  schema "tags" do
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
    |> put_slug()
    |> unique_constraint(:slug)
  end

  @doc """
  Turns a title into a URL-safe slug. Same rule the changeset uses, exposed
  so bulk operations can compute the slug→id mapping the DB will land on.
  """
  def slugify(title) when is_binary(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp put_slug(changeset) do
    case get_change(changeset, :title) do
      nil ->
        changeset

      title ->
        put_change(changeset, :slug, slugify(title))
    end
  end
end
