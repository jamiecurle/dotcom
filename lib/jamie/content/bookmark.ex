defmodule Jamie.Content.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  alias Jamie.Tags.Tag

  # The id is not auto-generated — it comes from linkding, the upstream source.
  # See the sync worker, which writes linkding's id straight into this column.
  @primary_key {:id, :integer, autogenerate: false}
  schema "bookmarks" do
    field :url, :string
    field :title, :string
    field :description, :string
    field :favicon, :string
    field :preview, :string

    timestamps(type: :utc_datetime)

    many_to_many :tags, Tag, join_through: "tags_bookmarks"
  end

  @doc false
  def changeset(bookmark, attrs) do
    bookmark
    |> cast(attrs, [:id, :url, :title, :description, :favicon, :preview])
    |> validate_required([:url, :title])
    |> unique_constraint(:url)
  end
end
