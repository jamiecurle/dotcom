defmodule Jamie.Repo.Migrations.AddOgHashToPosts do
  use Ecto.Migration

  def change do
    alter table(:blog_posts) do
      add :og_hash, :string
    end

    # The GC sweep looks up live hashes by this column.
    create index(:blog_posts, [:og_hash])
  end
end
