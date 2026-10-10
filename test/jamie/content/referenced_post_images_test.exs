defmodule Jamie.Content.ReferencedPostImagesTest do
  use Jamie.DataCase, async: true

  import Jamie.AccountsFixtures

  alias Jamie.Accounts.Scope
  alias Jamie.Content
  alias Jamie.Content.PostImageHelper
  alias Jamie.Support.ContentFixtures

  @a "11111111-1111-4111-8111-111111111111"
  @b "22222222-2222-4222-8222-222222222222"
  @c "33333333-3333-4333-8333-333333333333"

  describe "PostImageHelper.post_image_ids/1" do
    test "finds a reference whatever shape it takes" do
      text = """
      ![md](https://media.jamiecurle.com/posts/#{@a}.png) ![same line](https://media.jamiecurle.com/posts/#{@b}.JPG "a title")
      <img src="https://media.jamiecurle.com/cdn-cgi/image/width=1200/posts/#{String.upcase(@c)}.jpeg">
      """

      assert PostImageHelper.post_image_ids(text) == [@a, @b, @c]
    end

    test "ignores UUIDs that aren't under posts/" do
      text = "https://media.jamiecurle.com/opengraph/#{@a}.png and #{@b}.png"
      assert PostImageHelper.post_image_ids(text) == []
    end

    test "copes with nil" do
      assert PostImageHelper.post_image_ids(nil) == []
    end
  end

  describe "referenced_post_image_ids/0" do
    test "collects references from posts, notes and pending suggestions" do
      {:ok, post} =
        Content.create_post(
          ContentFixtures.post_attrs(markdown: "intro\n![](https://x/posts/#{@a}.png)\n")
        )

      {:ok, _note} =
        Content.create_note(
          ContentFixtures.note_attrs(markdown: "![](https://x/posts/#{@b}.png)")
        )

      {:ok, _suggestion} =
        Content.suggest_post_edit(Scope.for_user(user_fixture()), post.id, %{
          "old_string" => "intro",
          "new_string" => "![](https://x/posts/#{@c}.png)",
          "reason" => "add a picture"
        })

      assert Content.referenced_post_image_ids() == MapSet.new([@a, @b, @c])
    end

    test "a rejected suggestion doesn't keep an image alive" do
      {:ok, post} = Content.create_post(ContentFixtures.post_attrs(markdown: "intro\n"))
      scope = Scope.for_user(user_fixture())

      {:ok, suggestion} =
        Content.suggest_post_edit(scope, post.id, %{
          "old_string" => "intro",
          "new_string" => "![](https://x/posts/#{@c}.png)",
          "reason" => "add a picture"
        })

      {:ok, _} = Content.reject_suggestion(scope, suggestion.id)

      assert Content.referenced_post_image_ids() == MapSet.new()
    end
  end
end
