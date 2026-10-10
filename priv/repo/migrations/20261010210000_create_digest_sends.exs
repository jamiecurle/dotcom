defmodule Jamie.Repo.Migrations.CreateDigestSends do
  use Ecto.Migration

  # One row per digest emailed: which subscriber, for which period, with
  # which posts, and Postmark's message id so its webhooks can be matched
  # back to the send. The (subscriber, period) pair is unique, so a retried
  # or doubled job can't send the same digest twice.
  def change do
    create table(:digest_sends) do
      add :subscriber_id, references(:subscribers, type: :binary_id, on_delete: :nilify_all)
      # e.g. "daily:2026-10-11", "weekly:2026-10-16", "monthly:2026-10-28"
      add :period, :string, null: false
      add :frequency, :string, null: false
      add :post_ids, {:array, :integer}, null: false, default: []
      add :message_id, :string
      add :sent_at, :utc_datetime_usec, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:digest_sends, [:subscriber_id, :period])
    create index(:digest_sends, [:message_id])
    create index(:digest_sends, [:period])
  end
end
