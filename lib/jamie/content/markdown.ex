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

  @doc """
  The headings in a markdown document as `{level, text, anchor}`, in order.
  The anchor matches the id `to_html!/1` puts on the heading.
  """
  def toc(markdown) do
    {:ok, doc} = MDEx.parse_document(markdown)

    doc
    |> Enum.reduce([], fn
      %MDEx.Heading{level: level, nodes: children}, acc ->
        text = extract_text(children)
        [{level, text, slugify(text)} | acc]

      _node, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  @doc "Roughly 200 words a minute, never less than one."
  def reading_minutes(markdown) do
    words = markdown |> String.split(~r/\s+/, trim: true) |> length()
    max(1, div(words + 199, 200))
  end

  defp extract_text(nodes) do
    Enum.map_join(nodes, fn
      %MDEx.Text{literal: text} -> text
      %MDEx.Code{literal: text} -> text
      %{nodes: children} -> extract_text(children)
      _ -> ""
    end)
  end

  # Mirrors comrak's header ids: punctuation dropped, then every space
  # becomes a dash, so "A & B" is "a--b", not "a-b".
  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/u, "")
    |> String.replace(~r/\s/u, "-")
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
