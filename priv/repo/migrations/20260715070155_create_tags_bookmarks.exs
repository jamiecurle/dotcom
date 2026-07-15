defmodule Jamie.Repo.Migrations.CreateTagsBookmarks do
  use Ecto.Migration

  def change do
    create table(:tags_bookmarks, primary_key: false) do
      add :tag_id, references(:tag_tags)
      add :bookmark_id, references(:bookmarks, type: :integer)
    end

    create index(:tags_bookmarks, [:bookmark_id])
    create unique_index(:tags_bookmarks, [:tag_id, :bookmark_id])
  end
end
