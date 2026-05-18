defmodule Jamie.Repo.Migrations.PostsUpdatedAtUsec do
  use Ecto.Migration

  # Bump `blog_posts.updated_at` to microsecond precision so that
  # optimistic locking on update remains effective for writes that
  # land in the same wall-clock second.
  def up do
    alter table(:blog_posts) do
      modify :updated_at, :utc_datetime_usec, null: false
      modify :inserted_at, :utc_datetime_usec, null: false
    end
  end

  def down do
    alter table(:blog_posts) do
      modify :updated_at, :utc_datetime, null: false
      modify :inserted_at, :utc_datetime, null: false
    end
  end
end
