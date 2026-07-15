defmodule Jamie.PostTest do
  use Jamie.DataCase

  alias Jamie.Content

  alias Jamie.Support.ContentFixtures

  describe "og_hash is saved when post is created and updated" do
    setup do
      {:ok, post} = ContentFixtures.post_attrs() |> Content.create_post()

      %{post: post}
    end

    test "og_hash is saved when post is created", %{post: post} do
      assert post.og_hash == "cf69675124bddb8f7a455e7da5505f93"
    end

    test "og_hash is saved again when post is edited", %{post: post} do
      # edit the post
      {:ok, post_edited} = Content.update_post(post, %{"title" => "yes, this isn't the fixture"})

      refute post_edited.og_hash == "cf69675124bddb8f7a455e7da5505f93"
      assert post_edited.og_hash == "fb08df1a009cf3e9392d50fce4015da1"
    end
  end
end
