defmodule Jamie.Repo.Migrations.CreateBookmarks do
  use Ecto.Migration

  def change do
    create table(:bookmarks) do
      add :url, :string
      add :title, :string
      add :description, :text
      add :favicon, :string
      add :preview, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:bookmarks, [:url])
  end
end
