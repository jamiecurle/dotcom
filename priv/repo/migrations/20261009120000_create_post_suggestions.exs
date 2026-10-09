defmodule Jamie.Repo.Migrations.CreatePostSuggestions do
  use Ecto.Migration

  def change do
    create table(:post_suggestions) do
      add :post_id, references(:posts, on_delete: :delete_all), null: false
      add :old_string, :text, null: false
      add :new_string, :text, null: false
      add :reason, :text
      add :status, :string, null: false, default: "pending"
      add :resolved_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:post_suggestions, [:post_id])
    create index(:post_suggestions, [:status])
  end
end
