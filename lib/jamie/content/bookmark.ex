defmodule Jamie.Content.Bookmark do
  use Ecto.Schema
  import Ecto.Changeset

  schema "bookmarks" do
    field :url, :string
    field :title, :string
    field :user_id, :id

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(bookmark, attrs, user_scope) do
    bookmark
    |> cast(attrs, [:url, :title])
    |> validate_required([:url, :title])
    |> put_change(:user_id, user_scope.user.id)
  end
end
