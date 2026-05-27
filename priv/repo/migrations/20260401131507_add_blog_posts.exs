defmodule Jamie.Repo.Migrations.AddBlogPosts do
  use Ecto.Migration

  def change do
    create table(:blog_posts) do
      add :status, :string, null: false, default: "draft"
      add :title, :string
      add :description, :string
      add :markdown, :text
      add :html, :text
      timestamps(type: :utc_datetime)
    end
  end
end
