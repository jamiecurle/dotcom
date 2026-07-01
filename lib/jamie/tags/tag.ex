defmodule Jamie.Tags.Tag do
  use Ecto.Schema
  import Ecto.Changeset

  schema "tag_tags" do
    field :title, :string
    field :slug, :string
  end

  @doc false
  def changeset(tag, attrs) do
    tag
    |> cast(attrs, [:title])
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
