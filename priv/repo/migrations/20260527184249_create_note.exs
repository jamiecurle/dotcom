defmodule :"Elixir.Jamie.Repo.Migrations.CreateNote.ex" do
  use Ecto.Migration

  def change do
    create table(:blog_notes) do
      add :status, :string, null: false, default: "draft"
      add :title, :string
      add :markdown, :text
      add :html, :text
      add :published_on, :date
      add :edited_on, :date
      timestamps(type: :utc_datetime)
    end
  end
end
