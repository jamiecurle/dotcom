defmodule Jamie.Repo.Migrations.CreateTag do
  use Ecto.Migration

  def change do
    create table(:tag_tags) do
      add :title, :string
      add :slug, :string
    end

    create unique_index(:tag_tags, [:slug])
  end
end
