defmodule Jamie.Tags do
  @moduledoc """
  Context boundary for tags
  """

  import Ecto.Query, only: [from: 2]

  alias Jamie.Content.{
    Bookmark,
    Note,
    Post
  }

  alias Jamie.Repo
  alias Jamie.Tags.Tag

  @doc """
  Tags a Post or a Note.
  If the tag doesn't exist, it is created
  """

  @spec tag(Post.t() | Note.t() | Bookmark.t(), String.t()) :: {:ok | :error, any()}
  def tag(target, tag_title)

  def tag(%Bookmark{} = bookmark, tag_title) do
    with attrs <- %{title: tag_title},
         tag_cs <- changeset_tag(%Tag{}, attrs),
         {:ok, tag} <- upsert_tag(tag_cs) do
      # tag it
      tag_content(bookmark, tag.id)
    end
  end

  def tag(%Post{} = post, tag_title) do
    with attrs <- %{title: tag_title},
         tag_cs <- changeset_tag(%Tag{}, attrs),
         {:ok, tag} <- upsert_tag(tag_cs) do
      # tag it
      tag_content(post, tag.id)
    end
  end

  def tag(%Note{} = note, tag_title) do
    with attrs <- %{title: tag_title},
         tag_cs <- changeset_tag(%Tag{}, attrs),
         {:ok, tag} <- upsert_tag(tag_cs) do
      # tag it
      tag_content(note, tag.id)
    end
  end

  defp tag_content(%Bookmark{} = bookmark, tag_id) do
    Repo.insert_all(
      "tags_bookmarks",
      [%{bookmark_id: bookmark.id, tag_id: tag_id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(bookmark, :tags, force: true)}
  end

  defp tag_content(%Post{} = post, tag_id) do
    Repo.insert_all(
      "tags_posts",
      [%{post_id: post.id, tag_id: tag_id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(post, :tags, force: true)}
  end

  defp tag_content(%Note{} = note, tag_id) do
    Repo.insert_all(
      "tags_notes",
      [%{note_id: note.id, tag_id: tag_id}],
      on_conflict: :nothing
    )

    {:ok, Repo.preload(note, :tags)}
  end

  @doc """
  Bulk-tags many bookmarks from a list of Linkding `results` maps.

  Each result is expected to carry a `"url"` and a `"tag_names"` list of
  strings. `url_to_id` maps each result's url to the bookmark's real stored id
  (as returned by the bookmark upsert) — an incoming id can't be trusted here
  because a url that already existed keeps its original id on conflict.

  Runs in two DB round-trips regardless of how many bookmarks/tags there are:

    1. Upsert every distinct tag and read back its id. We use
       `on_conflict: {:replace, [:slug]}` rather than `:nothing` because
       Postgres only returns rows the statement actually touched, and we need
       ids for tags that already existed.
    2. Insert the join rows, ignoring any that are already present.
  """
  def tag_bookmarks_bulk(results, url_to_id) do
    tag_rows =
      results
      |> Enum.flat_map(fn r -> r["tag_names"] || [] end)
      |> Enum.map(&String.downcase/1)
      |> Enum.uniq()
      |> Enum.map(fn title -> %{title: title, slug: Tag.slugify(title)} end)

    if tag_rows == [] do
      {0, nil}
    else
      {_count, tags} =
        Repo.insert_all(Tag, tag_rows,
          on_conflict: {:replace, [:slug]},
          conflict_target: :slug,
          returning: [:id, :slug]
        )

      slug_to_id = Map.new(tags, &{&1.slug, &1.id})

      join_rows =
        results
        |> Enum.flat_map(&join_rows_for(&1, url_to_id, slug_to_id))
        |> Enum.uniq()

      Repo.insert_all("tags_bookmarks", join_rows, on_conflict: :nothing)
    end
  end

  defp join_rows_for(result, url_to_id, slug_to_id) do
    for title <- result["tag_names"] || [] do
      %{
        bookmark_id: Map.fetch!(url_to_id, result["url"]),
        tag_id: Map.fetch!(slug_to_id, Tag.slugify(title))
      }
    end
  end

  @doc """
  Makes `titles` the post's complete set of tags: missing tags are created,
  new ones attached, and any the post had that aren't in the list are
  detached (the tags themselves are kept, as bookmarks may use them).

  Titles are trimmed and lowercased; blanks and duplicates are ignored.
  Everything happens in one transaction.
  """
  def set_post_tags(%Post{} = post, titles) when is_list(titles) do
    titles =
      titles
      |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
      |> Enum.reject(&(&1 == ""))
      |> Enum.uniq()

    Repo.transact(fn ->
      tag_ids =
        Enum.map(titles, fn title ->
          {:ok, tag} = %Tag{} |> changeset_tag(%{title: title}) |> upsert_tag()
          tag.id
        end)

      Repo.delete_all(
        from(tp in "tags_posts", where: tp.post_id == ^post.id and tp.tag_id not in ^tag_ids)
      )

      Repo.insert_all(
        "tags_posts",
        Enum.map(tag_ids, &%{post_id: post.id, tag_id: &1}),
        on_conflict: :nothing
      )

      {:ok, Repo.preload(post, :tags, force: true)}
    end)
  end

  @doc """
  Up to `limit` existing tag titles containing `query`, for suggesting as
  you type. Prefix matches come first, then the rest alphabetically; titles
  in `except` (the ones already chosen) are left out.
  """
  def suggest_tags(query, except \\ [], limit \\ 6) when is_binary(query) do
    query = query |> String.trim() |> String.downcase()

    if query == "" do
      []
    else
      escaped = String.replace(query, ~r/[\\%_]/, "\\\\\\0")

      from(t in Tag,
        where: ilike(t.title, ^"%#{escaped}%") and t.title not in ^except,
        order_by: [
          asc: fragment("CASE WHEN ? ILIKE ? THEN 0 ELSE 1 END", t.title, ^"#{escaped}%"),
          asc: t.title
        ],
        limit: ^limit,
        select: t.title
      )
      |> Repo.all()
    end
  end

  @doc """
  The titles of a post's tags, alphabetically.
  """
  def post_tag_titles(%Post{id: nil}), do: []

  def post_tag_titles(%Post{} = post) do
    from(t in Tag,
      join: tp in "tags_posts",
      on: tp.tag_id == t.id,
      where: tp.post_id == ^post.id,
      order_by: t.title,
      select: t.title
    )
    |> Repo.all()
  end

  @doc """
  A post's tags, alphabetically.
  """
  def post_tags(%Post{id: nil}), do: []

  def post_tags(%Post{} = post) do
    from(t in Tag,
      join: tp in "tags_posts",
      on: tp.tag_id == t.id,
      where: tp.post_id == ^post.id,
      order_by: t.title
    )
    |> Repo.all()
  end

  @doc """
  Gets a tag by slug. Raises `Ecto.NoResultsError` (a 404) when there's none.
  """
  def get_tag_by_slug!(slug), do: Repo.get_by!(Tag, slug: slug)

  @doc """
  A tag's published posts, newest first.
  """
  def published_posts(%Tag{} = tag) do
    from(p in Post,
      join: tp in "tags_posts",
      on: tp.post_id == p.id,
      where: tp.tag_id == ^tag.id and p.status == :published,
      order_by: [desc: p.published_on]
    )
    |> Repo.all()
  end

  @doc """
  A tag's published notes, newest first.
  """
  def published_notes(%Tag{} = tag) do
    from(n in Note,
      join: tn in "tags_notes",
      on: tn.note_id == n.id,
      # a note only gets a published_on when it's saved as published; skip any
      # that slipped through without one rather than crash the sort
      where: tn.tag_id == ^tag.id and n.status == :published and not is_nil(n.published_on),
      order_by: [desc: n.published_on]
    )
    |> Repo.all()
  end

  @doc """
  Everything published under a tag - posts and notes - newest first.

  Returns the `Post` and `Note` structs themselves, mixed together; both have
  the `id`, `title` and `published_on` a listing needs, and the struct tells
  the caller which kind each one is.
  """
  def published_content(%Tag{} = tag) do
    (published_posts(tag) ++ published_notes(tag))
    |> Enum.sort_by(& &1.published_on, {:desc, Date})
  end

  @doc """
  Gets a tag by title
  """
  def tag_by_title(title) do
    case Repo.get_by(Tag, title: title |> String.downcase()) do
      nil -> {:error, :not_found}
      %Tag{} = tag -> {:ok, tag}
    end
  end

  @doc """
  Inserts a tag, or returns the existing row if the slug already exists.
  """
  def upsert_tag(%Ecto.Changeset{} = changeset) do
    changeset
    |> Repo.insert(
      on_conflict: {:replace, [:slug]},
      conflict_target: :slug,
      returning: true
    )
  end

  @doc """
  Create a tag
  """
  def create_tag(attrs) do
    case changeset_tag(%Tag{}, attrs) do
      %{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> changeset
    end
  end

  @doc """
  Creates a changeset for a tag
  """
  def changeset_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end
end
