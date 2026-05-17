defmodule Jamie.Blog do
  @moduledoc """
  The blog context boundary.
  """

  alias Jamie.Blog.Post
  alias Jamie.Repo
  import Ecto.Query
  alias Jamie.Accounts.Scope

  @doc """
  returns a changeset for a post
  """
  def change_post(%Post{} = post, attrs \\ %{}) do
    Post.changeset(post, attrs)
  end

  @doc """
  Creates a post
  """
  def create_post(attrs) do
    case Post.changeset(%Post{}, attrs) do
      %{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> changeset
    end
  end

  @doc """
  Gets a post by slug
  """
  def get_post_by_slug!(slug, %Scope{user: user}) when not is_nil(user) do
    Post
    |> where(slug: ^slug)
    |> Repo.one!()
  end

  def get_post_by_slug!(slug, nil), do: get_post_by_slug!(slug)

  def get_post_by_slug!(slug) do
    Post
    |> where(status: :published)
    |> where(slug: ^slug)
    |> Repo.one!()
  end

  @doc """
  Gets a post by id
  """
  def get_post!(id) do
    Post
    |> Repo.get!(id)
  end

  @doc """
  Updates a post
  """
  def update_post(%Post{} = post, attrs) do
    post
    |> Post.changeset(attrs)
    |> Repo.update()
    |> case do
      {:ok, updated_post} ->
        Phoenix.PubSub.broadcast(
          Jamie.PubSub,
          "post:#{updated_post.id}",
          {:post_updated, updated_post}
        )

        {:ok, updated_post}

      error ->
        error
    end
  end

  @doc """
  Gets published posts ordered by published date descending
  """

  def published_posts(%Scope{user: user}) when not is_nil(user) do
    from(p in Post, order_by: [desc: p.published_on])
    |> Repo.all()
  end

  def published_posts(nil) do
    from(p in Post, where: p.status == :published, order_by: [desc: p.published_on])
    |> Repo.all()
  end

  def published_posts do
    from(p in Post, where: p.status == :published, order_by: [desc: p.published_on])
    |> Repo.all()
  end

  @doc """
  Returns the N most recently published posts.
  """
  def latest_published_posts(n) when is_integer(n) and n >= 0 do
    from(p in Post,
      where: p.status == :published,
      order_by: [desc: p.published_on],
      limit: ^n
    )
    |> Repo.all()
  end

  @doc """
  Gets all posts order by date descending
  """
  def all_posts do
    from(p in Post)
    |> order_by(desc: :id)
    |> Repo.all()
  end
end
