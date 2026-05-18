defmodule Jamie.Blog.PostRevision do
  @moduledoc """
  A single saved revision of a post — either a `diffy` diff against the
  previous revision or a full-content snapshot.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "post_revisions" do
    field :revision_number, :integer, read_after_writes: true
    field :diff, :string
    field :snapshot, :string
    field :is_snapshot, :boolean, default: false
    field :name, :string
    field :saved_at, :utc_datetime_usec

    belongs_to :post, Jamie.Blog.Post
  end

  def changeset(rev, attrs) do
    rev
    |> cast(attrs, [:post_id, :diff, :snapshot, :is_snapshot, :name, :saved_at])
    |> validate_required([:post_id, :is_snapshot, :saved_at])
    |> foreign_key_constraint(:post_id)
  end
end
