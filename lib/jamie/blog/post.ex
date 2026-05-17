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

    timestamps()
  end

  def statuses, do: @statuses

  @doc false
  def changeset(post, attrs) do
    post
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> convert_markdown_to_html()
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

  defp convert_markdown_to_html(changeset) do
    case get_change(changeset, :markdown) do
      nil ->
        changeset

      markdown ->
        html =
          MDEx.to_html!(markdown,
            extension: [
              strikethrough: true,
              tagfilter: false,
              table: true,
              footnotes: true,
              autolink: true,
              tasklist: true,
              header_ids: ""
            ],
            sanitize: [
              add_tags: ["iframe", "section"],
              add_tag_attributes: %{
                "iframe" => [
                  "src",
                  "width",
                  "height",
                  "frameborder",
                  "allow",
                  "allowfullscreen",
                  "loading",
                  "title",
                  "referrerpolicy"
                ]
              },
              add_generic_attributes: ["id", "class"],
              add_generic_attribute_prefixes: ["aria-", "data-"],
              add_url_schemes: ["https"],
              set_tag_attribute_values: %{
                "iframe" => %{"allow" => "picture-in-picture"}
              }
            ],
            parse: [smart: true],
            render: [unsafe: true],
            syntax_highlight: [formatter: :html_linked]
          )
          |> rewrite_image_urls()

        put_change(changeset, :html, html)
    end
  end

  # Rewrites <img src="https://media.jamiecurle.com/<key>"> to route through
  # Cloudflare's on-the-fly resizer. Skips already-transformed URLs.
  def rewrite_image_urls(html) do
    host = Application.get_env(:jamie, :images)[:host]
    transform = Application.get_env(:jamie, :images)[:transform]

    Regex.replace(
      ~r{(<img[^>]*src=")https://#{host}/(?!cdn-cgi/)([^"]+)},
      html,
      "\\1https://#{host}/#{transform}/\\2"
    )
  end
end
