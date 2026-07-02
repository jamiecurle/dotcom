defmodule Jamie.Repo.Migrations.CreateTag do
  use Ecto.Migration

  def change do
    create table(:tag_tags) do
      add :title, :string
      add :slug, :string
      add :post_id, references(:blog_posts)
      add :note_id, references(:blog_notes)
    end

    create index(:tag_tags, [:title])
    create unique_index(:tag_tags, [:slug])
  end
end
