defmodule Jamie.BlogPostTest do
  use Jamie.DataCase

  alias Jamie.Blog

  alias Jamie.Support.BlogFixtures

  describe "og_hash is saved when post is created and updated" do
    setup do
      {:ok, post} = BlogFixtures.post_attrs() |> Blog.create_post()

      %{post: post}
    end

    test "og_hash is saved when post is created", %{post: post} do
      assert post.og_hash == "cfec820f6ea2a894beb0a272cc507f04"
    end

    test "og_hash is saved again when post is edited", %{post: post} do
      # edit the post
      {:ok, post_edited} = Blog.update_post(post, %{"title" => "yes, this isn't the fixture"})

      refute post_edited.og_hash == "cfec820f6ea2a894beb0a272cc507f04"
      assert post_edited.og_hash == "fb08df1a009cf3e9392d50fce4015da1"
    end
  end
end
