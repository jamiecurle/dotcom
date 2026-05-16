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

    # Optional LLM-targeted variant. When `{page}.llm.md` is present, the
    # `Accept: text/markdown` path serves it instead of `{page}.md`. HTML
    # rendering is unaffected. Declared as an external resource so edits
    # trigger a recompile even when the file does not yet exist.
    llm_path = Path.join([:code.priv_dir(:jamie), "static_markdown", "#{page}.llm.md"])
    @external_resource llm_path
    llm_body = if File.exists?(llm_path), do: File.read!(llm_path), else: nil
    Module.put_attribute(__MODULE__, :"#{page}_llm_md", llm_body)
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

  @doc """
  LLM-targeted markdown for a static page, used by the `Accept: text/markdown`
  pipeline. Falls back to `static_page_markdown/1` when no `.llm.md` variant
  exists. Resolved at compile time so each clause has a fixed body.
  """
  for page <- @static_pages do
    llm_body = Module.get_attribute(__MODULE__, :"#{page}_llm_md")

    if is_nil(llm_body) do
      def static_page_llm_markdown(unquote(page)), do: static_page_markdown(unquote(page))
    else
      def static_page_llm_markdown(unquote(page)), do: unquote(llm_body)
    end
  end

  @doc "HTML rendering of a static page, derived from the markdown source."
  def static_page_html(page) when page in @static_pages do
    page |> static_page_markdown() |> MDEx.to_html!()
  end

  @doc """
  Render markdown for a request whose path has been split into
  `path_info` (as on `Plug.Conn`).
  """
  def render(["about"]), do: {:ok, static_page_llm_markdown(:about)}
  def render(["privacy"]), do: {:ok, static_page_llm_markdown(:privacy)}
  def render(["projects"]), do: {:ok, static_page_llm_markdown(:projects)}
  def render([]), do: {:ok, static_page_llm_markdown(:about)}

  def render(["posts", slug]) do
    post = Blog.get_post_by_slug!(slug)
    {:ok, post_front_matter(post) <> (post.markdown || "")}
  rescue
    Ecto.NoResultsError -> :passthrough
  end

  def render(_path_info), do: :passthrough
end
