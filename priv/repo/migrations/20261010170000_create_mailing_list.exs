defmodule Jamie.Repo.Migrations.CreateMailingList do
  use Ecto.Migration

  def change do
    # One row per subscriber. The uuid primary key doubles as the secret in
    # their /subscribe/<id> manage link, so it must never be guessable or
    # shown anywhere else. Unsubscribing deletes the row.
    create table(:subscribers, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :citext, null: false
      add :everything, :boolean, null: false, default: false
      add :worlds, {:array, :string}, null: false, default: []
      add :frequency, :string, null: false
      add :status, :string, null: false, default: "pending"

      # double opt-in: only a hash of the emailed token is kept
      add :confirm_token_hash, :binary
      add :confirm_sent_at, :utc_datetime_usec
      add :confirmed_at, :utc_datetime_usec
      # which privacy notice they agreed to; no IP or other metadata
      add :consent_notice_version, :string

      add :last_sent_at, :utc_datetime_usec
      add :soft_bounce_count, :integer, null: false, default: 0

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:subscribers, [:email])
    create unique_index(:subscribers, [:confirm_token_hash])
    create index(:subscribers, [:status, :frequency])

    # Addresses that must never be mailed again (hard bounces, spam
    # complaints). Only a keyed hash of the address is kept, enough to check
    # a new sign-up against without holding the address itself.
    create table(:suppressions) do
      add :email_hash, :binary, null: false
      add :reason, :string, null: false

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:suppressions, [:email_hash])
  end
end
