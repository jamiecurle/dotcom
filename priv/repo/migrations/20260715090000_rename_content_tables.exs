defmodule Jamie.Repo.Migrations.RenameContentTables do
  use Ecto.Migration

  # Renames the blog-era tables to their final names: blog_posts -> posts,
  # post_revisions -> posts_revisions, blog_notes -> notes.
  #
  # Postgres carries indexes, constraints, sequences and triggers across a table
  # rename automatically, but they keep their old names. That matters beyond
  # tidiness: Ecto derives constraint names from the schema source, so
  # `unique_constraint(:slug)` on Post looks for `posts_slug_index`. Leave the
  # index named `blog_posts_slug_index` and the changeset stops turning a
  # duplicate slug into a validation error and raises Postgrex.Error instead.
  # So every supporting object gets renamed alongside its table.
  #
  # Renames are catalog-only, so these are instant regardless of table size.

  def up do
    rename table(:blog_posts), to: table(:posts)

    execute "ALTER INDEX blog_posts_pkey RENAME TO posts_pkey"
    execute "ALTER INDEX blog_posts_slug_index RENAME TO posts_slug_index"
    execute "ALTER INDEX blog_posts_og_hash_index RENAME TO posts_og_hash_index"
    execute "ALTER SEQUENCE blog_posts_id_seq RENAME TO posts_id_seq"

    rename table(:post_revisions), to: table(:posts_revisions)

    execute "ALTER INDEX post_revisions_pkey RENAME TO posts_revisions_pkey"

    execute "ALTER INDEX post_revisions_post_id_saved_at_index RENAME TO posts_revisions_post_id_saved_at_index"

    execute "ALTER SEQUENCE post_revisions_id_seq RENAME TO posts_revisions_id_seq"

    # Renaming an index renames the primary key / unique constraint it backs,
    # but a foreign key has no backing index - pg_constraint must be told directly.
    execute "ALTER TABLE posts_revisions RENAME CONSTRAINT post_revisions_post_id_fkey TO posts_revisions_post_id_fkey"

    rename table(:blog_notes), to: table(:notes)

    execute "ALTER INDEX blog_notes_pkey RENAME TO notes_pkey"
    execute "ALTER SEQUENCE blog_notes_id_seq RENAME TO notes_id_seq"

    # The trigger itself follows the table, but plpgsql resolves table names in
    # the function body at execution time - every insert would fail with
    # `relation "post_revisions" does not exist` until the body is replaced.
    execute """
    create or replace function set_revision_number()
    returns trigger as $$
    begin
      select coalesce(max(revision_number), 0) + 1
      into new.revision_number
      from posts_revisions
      where post_id = new.post_id;
      return new;
    end;
    $$ language plpgsql;
    """
  end

  def down do
    execute """
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
    """

    execute "ALTER SEQUENCE notes_id_seq RENAME TO blog_notes_id_seq"
    execute "ALTER INDEX notes_pkey RENAME TO blog_notes_pkey"

    rename table(:notes), to: table(:blog_notes)

    execute "ALTER TABLE posts_revisions RENAME CONSTRAINT posts_revisions_post_id_fkey TO post_revisions_post_id_fkey"

    execute "ALTER SEQUENCE posts_revisions_id_seq RENAME TO post_revisions_id_seq"

    execute "ALTER INDEX posts_revisions_post_id_saved_at_index RENAME TO post_revisions_post_id_saved_at_index"

    execute "ALTER INDEX posts_revisions_pkey RENAME TO post_revisions_pkey"

    rename table(:posts_revisions), to: table(:post_revisions)

    execute "ALTER SEQUENCE posts_id_seq RENAME TO blog_posts_id_seq"
    execute "ALTER INDEX posts_og_hash_index RENAME TO blog_posts_og_hash_index"
    execute "ALTER INDEX posts_slug_index RENAME TO blog_posts_slug_index"
    execute "ALTER INDEX posts_pkey RENAME TO blog_posts_pkey"

    rename table(:posts), to: table(:blog_posts)
  end
end
