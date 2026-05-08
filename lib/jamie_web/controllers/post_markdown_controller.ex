defmodule JamieWeb.PostMarkdownController do
  use JamieWeb, :controller

  alias Jamie.Blog
  alias JamieWeb.MarkdownRenderer

  def show(conn, %{"slug" => slug}) do
    post = Blog.get_post_by_slug!(slug)
    body = MarkdownRenderer.post_front_matter(post) <> (post.markdown || "")

    conn
    |> put_resp_content_type("text/markdown")
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> send_resp(200, body)
  end
end
