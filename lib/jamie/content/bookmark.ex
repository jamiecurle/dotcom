defmodule Jamie.Content.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmarks" do
    field :url, :string
    field :title, :string
    field :description, :string
    field :favicon, :string
    field :preview, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:url, :title, :description, :favicon, :preview])
    |> validate_required([:url, :title])
    |> unique_constraint(:url)
  end
end
