defmodule Jamie.Repo.Migrations.AddPostRevisions do
  use Ecto.Migration

  def up do
    create table(:post_revisions) do
      add :post_id, references(:blog_posts, on_delete: :delete_all), null: false
      add :revision_number, :integer, null: false, default: 0
      add :diff, :text
      add :snapshot, :text
      add :is_snapshot, :boolean, null: false, default: false
      add :name, :string, size: 255
      add :saved_at, :utc_datetime_usec, null: false, default: fragment("now()")
    end

    create index(:post_revisions, [:post_id, :saved_at])

    execute("""
    create or replace function set_revision_number()
    returns trigger as $$
    begin
      select coalesce(max(revision_number), 0) + 1
      into new.revision_number
      from post_revisions
      where post_id = new.post_id;
      return new;
    end;
    $$ language plpgsql;
    """)

    execute("""
    create trigger set_revision_number_on_insert
    before insert on post_revisions
    for each row execute function set_revision_number();
    """)
  end

  def down do
    execute("drop trigger if exists set_revision_number_on_insert on post_revisions;")
    execute("drop function if exists set_revision_number();")
    drop table(:post_revisions)
  end
end
