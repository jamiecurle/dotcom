defmodule Jamie.Repo.Migrations.AddConsentedAtToSubscribers do
  use Ecto.Migration

  # When they ticked the box agreeing to the privacy notice, alongside the
  # existing consent_notice_version (which version they agreed to).
  def change do
    alter table(:subscribers) do
      add :consented_at, :utc_datetime_usec
    end
  end
end
