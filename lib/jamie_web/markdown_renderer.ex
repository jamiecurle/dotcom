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

  # For each static page, read `{page}.md` and (optionally) `{page}.llm.md`
  # at compile time, then generate the per-page accessor clauses. The LLM
  # variant falls back to the regular body when no `.llm.md` exists.
  for page <- @static_pages, base = Path.join(:code.priv_dir(:jamie), "static_markdown") do
    md_path = Path.join(base, "#{page}.md")
    llm_path = Path.join(base, "#{page}.llm.md")
    @external_resource md_path
    @external_resource llm_path
    md_body = File.read!(md_path)
    llm_body = if File.exists?(llm_path), do: File.read!(llm_path), else: md_body

    def static_page_markdown(unquote(page)), do: unquote(md_body)
    def static_page_llm_markdown(unquote(page)), do: unquote(llm_body)
    def render([unquote(to_string(page))]), do: {:ok, unquote(llm_body)}
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

  @doc "HTML rendering of a static page, derived from the markdown source."
  def static_page_html(page) when page in @static_pages do
    page |> static_page_markdown() |> MDEx.to_html!()
  end

  @doc """
  Render markdown for a request whose path has been split into
  `path_info` (as on `Plug.Conn`). Returns `{:ok, body}` or `:passthrough`.
  """
  def render([]), do: render(["about"])

  def render(["posts", slug]) do
    post = Blog.get_post_by_slug!(slug)
    {:ok, post_front_matter(post) <> (post.markdown || "")}
  rescue
    Ecto.NoResultsError -> :passthrough
  end

  def render(_path_info), do: :passthrough

  @doc """
  Whether the given `path_info` has a markdown rendering available. Used by
  the root layout to decide whether to advertise an `<link rel="alternate"
  type="text/markdown">` for agents.
  """
  def has_markdown?(path_info), do: match?({:ok, _}, render(path_info))
end
