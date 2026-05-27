defmodule Jamie.Markdown do
  @moduledoc """
  A central module for parsing markdown consistently.
  """
  import Ecto.Changeset, only: [put_change: 3, get_change: 2]

  def to_html!(%Ecto.Changeset{} = changeset) do
    case get_change(changeset, :markdown) do
      nil ->
        changeset

      markdown ->
        put_change(
          changeset,
          :html,
          to_html!(markdown)
        )
    end
  end

  def to_html!(markdown) do
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
