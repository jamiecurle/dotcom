defmodule Jamie.Repo.Migrations.NotesCustomCss do
  use Ecto.Migration

  def change do
    alter table(:notes) do
      add :custom_css, :text
    end
  end
end
