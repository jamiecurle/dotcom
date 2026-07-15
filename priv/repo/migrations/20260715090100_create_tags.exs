defmodule Jamie.Repo.Migrations.CreateTags do
  use Ecto.Migration

  def change do
    create table(:tags) do
      add :title, :string
      add :slug, :string
    end

    create index(:tags, [:title])
    create unique_index(:tags, [:slug])

    create table(:tags_posts, primary_key: false) do
      add :tag_id, references(:tags)
      add :post_id, references(:posts)
    end

    create index(:tags_posts, [:post_id])
    create unique_index(:tags_posts, [:tag_id, :post_id])

    create table(:tags_notes, primary_key: false) do
      add :tag_id, references(:tags)
      add :note_id, references(:notes)
    end

    create index(:tags_notes, [:note_id])
    create unique_index(:tags_notes, [:tag_id, :note_id])
  end
end
