defmodule Jamie.Blog.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:draft, :published, :hidden]
  @required_fields [:status, :description, :title, :markdown]
  @optional_fields [:html, :slug, :edited_on, :published_on]

  schema "blog_posts" do
    field :status, Ecto.Enum, values: @statuses, default: :draft

    field :title, :string
    field :description, :string
    field :markdown, :string
    field :html, :string
    field :slug, :string
    field :published_on, :date
    field :edited_on, :date

    timestamps(type: :utc_datetime_usec)
  end

  def statuses, do: @statuses

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> Jamie.Markdown.to_html!()
    |> slugify()
    |> published_on()
    |> unique_constraint(:slug)
  end

  defp published_on(changeset) do
    case get_change(changeset, :status) do
      :published ->
        put_change(changeset, :published_on, Date.utc_today())

      _ ->
        changeset
    end
  end

  defp slugify(changeset) do
    case get_change(changeset, :title) do
      nil ->
        changeset

      title ->
        slug =
          title
          |> String.downcase()
          |> String.replace(~r/[^a-z0-9]+/, "-")
          |> String.trim("-")

        put_change(changeset, :slug, slug)
    end
  end
end
