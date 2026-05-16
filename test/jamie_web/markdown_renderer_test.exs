defmodule JamieWeb.MarkdownRendererTest do
  use Jamie.DataCase, async: true

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures
  alias JamieWeb.MarkdownRenderer

  describe "has_markdown?/1" do
    test "true for the root and static pages" do
      assert MarkdownRenderer.has_markdown?([])
      assert MarkdownRenderer.has_markdown?(["about"])
      assert MarkdownRenderer.has_markdown?(["privacy"])
      assert MarkdownRenderer.has_markdown?(["projects"])
    end

    test "false for unsupported paths" do
      refute MarkdownRenderer.has_markdown?(["users", "log-in"])
      refute MarkdownRenderer.has_markdown?(["nope"])
      refute MarkdownRenderer.has_markdown?(["posts"])
    end

    test "true for a published post, false for a draft or missing slug" do
      {:ok, published} =
        BlogFixtures.blog_attrs(title: "Published Markdown", status: :published)
        |> Blog.create_post()

      {:ok, draft} =
        BlogFixtures.blog_attrs(title: "Draft Markdown", status: :draft)
        |> Blog.create_post()

      assert MarkdownRenderer.has_markdown?(["posts", published.slug])
      refute MarkdownRenderer.has_markdown?(["posts", draft.slug])
      refute MarkdownRenderer.has_markdown?(["posts", "does-not-exist"])
    end
  end
end
