defmodule Jamie.Repo.Migrations.AddBlueskyToPosts do
  use Ecto.Migration

  # Where a post lives on the AT Protocol once it has been published there:
  # the Bluesky post that announces it (uri + cid make a strong ref) and the
  # site.standard.document record that holds the post itself.
  def change do
    alter table(:posts) do
      add :bluesky_uri, :string
      add :bluesky_cid, :string
      add :bluesky_posted_at, :utc_datetime_usec
      add :standard_document_uri, :string
    end
  end
end
