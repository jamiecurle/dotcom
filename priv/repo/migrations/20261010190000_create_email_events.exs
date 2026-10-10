defmodule Jamie.Repo.Migrations.CreateEmailEvents do
  use Ecto.Migration

  # What Postmark tells us about mail we sent: deliveries, bounces, spam
  # complaints and suppression changes. Kept so deliverability can be
  # watched closely, but never the address itself: events are tied to an
  # address by the same keyed hash as suppressions, so they outlive an
  # unsubscribe without keeping who it was.
  def change do
    create table(:email_events) do
      add :record_type, :string, null: false
      # Postmark's own bounce type and code, e.g. "HardBounce" / 1
      add :type, :string
      add :type_code, :integer
      add :message_id, :string
      add :message_stream, :string
      add :email_hash, :binary
      add :subscriber_id, references(:subscribers, type: :binary_id, on_delete: :nilify_all)
      add :occurred_at, :utc_datetime_usec
      # what was done about it: suppressed, deleted, counted, suspended...
      add :action, :string
      # the payload with the address and message dump taken out
      add :payload, :map, null: false
      # Postmark retries webhooks; this makes each event count once
      add :dedupe_key, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:email_events, [:dedupe_key])
    create index(:email_events, [:record_type, :occurred_at])
    create index(:email_events, [:email_hash])
    create index(:email_events, [:message_id])
    create index(:email_events, [:subscriber_id])
  end
end
