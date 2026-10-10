defmodule Jamie.Repo.Migrations.AddBlueskyHiddenRepliesToPosts do
  use Ecto.Migration

  # Replies to a post's Bluesky announcement I've chosen to keep off the
  # blog, by at:// uri. They stay on Bluesky; this only hides them here.
  def change do
    alter table(:posts) do
      add :bluesky_hidden_replies, {:array, :string}, null: false, default: []
    end
  end
end
