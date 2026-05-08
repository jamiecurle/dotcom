defmodule JamieWeb.MarkdownRenderer do
  @moduledoc """
  Renders markdown bodies for the routes that participate in
  `Accept: text/markdown` content negotiation, and is the single source
  of truth for the static page bodies (about, privacy, projects).

  Each renderer returns either `{:ok, body}` or `:passthrough`. A
  `:passthrough` means the negotiation plug should leave the conn alone
  so the regular HTML pipeline (LiveView, controller) handles the
  request — useful for unsupported paths and for missing/draft posts
  where the HTML 404 path is the right answer.
  """

  alias Jamie.Blog

  @static_pages ~w(about privacy projects)a

  for page <- @static_pages do
    path = Path.join([:code.priv_dir(:jamie), "static_markdown", "#{page}.md"])
    @external_resource path
    Module.put_attribute(__MODULE__, :"#{page}_md", File.read!(path))
  end

  @doc "Build the YAML front-matter block prepended to a post's markdown."
  def post_front_matter(post) do
    """
    ---
    title: #{post.title}
    description: #{post.description}
    published_on: #{post.published_on}
    edited_on: #{post.edited_on}
    url: #{JamieWeb.Endpoint.url()}/posts/#{post.slug}
    author: Jamie Curle
    copyright: Copyright Jamie Curle. All rights reserved.
    license: Reading and summarising permitted. Reproduction and AI training prohibited.
    ---

    """
  end

  @doc "Raw markdown source for a static page (`:about`, `:privacy`, `:projects`)."
  def static_page_markdown(:about), do: @about_md
  def static_page_markdown(:privacy), do: @privacy_md
  def static_page_markdown(:projects), do: @projects_md

  @doc "HTML rendering of a static page, derived from the markdown source."
  def static_page_html(page) when page in @static_pages do
    page |> static_page_markdown() |> MDEx.to_html!()
  end

  @doc """
  Render markdown for a request whose path has been split into
  `path_info` (as on `Plug.Conn`).
  """
  def render(["about"]), do: {:ok, static_page_markdown(:about)}
  def render(["privacy"]), do: {:ok, static_page_markdown(:privacy)}
  def render(["projects"]), do: {:ok, static_page_markdown(:projects)}
  def render([]), do: {:ok, archive_index()}

  def render(["posts", slug]) do
    post = Blog.get_post_by_slug!(slug)
    {:ok, post_front_matter(post) <> (post.markdown || "")}
  rescue
    Ecto.NoResultsError -> :passthrough
  end

  def render(_path_info), do: :passthrough

  defp archive_index do
    posts = Blog.published_posts()
    base = JamieWeb.Endpoint.url()

    grouped =
      posts
      |> Enum.group_by(& &1.published_on.year)
      |> Enum.sort_by(fn {year, _} -> year end, :desc)

    body =
      Enum.map_join(grouped, "\n", fn {year, year_posts} ->
        lines =
          year_posts
          |> Enum.sort_by(& &1.published_on, {:desc, Date})
          |> Enum.map_join("\n", fn post ->
            "- [#{post.title}](#{base}/posts/#{post.slug}) — #{post.published_on}"
          end)

        "## #{year}\n\n#{lines}\n"
      end)

    "# Archive\n\n" <> body
  end
end
