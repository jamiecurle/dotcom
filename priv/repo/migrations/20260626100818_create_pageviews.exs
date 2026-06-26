defmodule Jamie.Repo.Migrations.CreatePageviews do
  use Ecto.Migration

  def change do
    create table(:pageviews) do
      add :path, :string, null: false
      add :referrer_host, :string
      add :browser, :string
      add :os, :string
      add :device_type, :string
      add :country, :string
      add :visitor_hash, :string, null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    # Dashboard queries filter by time window and group by these dimensions.
    create index(:pageviews, [:inserted_at])
    create index(:pageviews, [:path])
    create index(:pageviews, [:referrer_host])

    # Unique-visitor counts dedupe on (visitor_hash, day); this supports it.
    create index(:pageviews, [:visitor_hash])
  end
end
