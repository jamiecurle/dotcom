defmodule Jamie.Tags.PostTagsTest do
  use Jamie.DataCase, async: true

  alias Jamie.Content
  alias Jamie.Repo
  alias Jamie.Support.ContentFixtures
  alias Jamie.Tags
  alias Jamie.Tags.Tag

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs())
    %{post: post}
  end

  test "sets tags, normalising and de-duplicating titles", %{post: post} do
    assert {:ok, _} = Tags.set_post_tags(post, [" Elixir", "woodland ", "ELIXIR", ""])
    assert Tags.post_tag_titles(post) == ["elixir", "woodland"]
  end

  test "replaces the whole set, keeping detached tags around", %{post: post} do
    {:ok, _} = Tags.set_post_tags(post, ["elixir", "woodland"])
    {:ok, _} = Tags.set_post_tags(post, ["woodland", "workshop"])

    assert Tags.post_tag_titles(post) == ["woodland", "workshop"]
    assert Repo.get_by(Tag, slug: "elixir")
  end

  test "an empty list clears the post's tags", %{post: post} do
    {:ok, _} = Tags.set_post_tags(post, ["elixir"])
    {:ok, _} = Tags.set_post_tags(post, [])

    assert Tags.post_tag_titles(post) == []
  end

  test "reuses existing tags rather than duplicating them", %{post: post} do
    {:ok, existing} = Tags.create_tag(%{title: "elixir"})
    {:ok, tagged} = Tags.set_post_tags(post, ["Elixir"])

    assert [%Tag{id: id}] = tagged.tags
    assert id == existing.id
  end

  test "other posts keep their own tags", %{post: post} do
    {:ok, other} = Content.create_post(ContentFixtures.post_attrs(title: "Other"))
    {:ok, _} = Tags.set_post_tags(other, ["elixir"])
    {:ok, _} = Tags.set_post_tags(post, [])

    assert Tags.post_tag_titles(other) == ["elixir"]
  end
end
