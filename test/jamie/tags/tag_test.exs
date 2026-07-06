defmodule Jamie.Tags.Test do
  use Jamie.DataCase

  alias Jamie.Blog
  alias Jamie.Repo
  alias Jamie.Support.BlogFixtures
  alias Jamie.Tags
  alias Jamie.Tags.Tag

  describe "Tags.tag/2" do
    test "works with existing tag on an post, then a note" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make the tag and tag the post
      {:ok, tag} = Tags.create_tag(%{title: "wallop"})

      {:ok, post} =
        BlogFixtures.post_attrs(status: :published)
        |> Blog.create_post()

      {:ok, post_returned} = Tags.tag(post, "wallop")

      # we have one tag
      assert 1 == Repo.aggregate(Tag, :count)

      # and it is now on our post
      assert tag in post_returned.tags

      # now tag the note
      {:ok, note} =
        BlogFixtures.note_attrs(status: :published)
        |> Blog.create_note()

      {:ok, note_returned} = Tags.tag(note, "wallop")

      # we still have one tag
      assert 1 == Repo.aggregate(Tag, :count)

      # and it is now on our note AND our post
      assert tag in note_returned.tags
      assert tag in post_returned.tags
    end

    test "works with a note and a non-existing tag" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make a note
      {:ok, note} =
        BlogFixtures.note_attrs(status: :published)
        |> Blog.create_note()

      # tag it
      {:ok, note} = Tags.tag(note, "wallop")

      # we have one tag
      assert 1 == Repo.aggregate(Tag, :count)

      # and it is on the note
      %{tags: [tag]} = note
      assert tag.title == "wallop"
    end

    test "works with a post and an existing tag schema" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make a post
      {:ok, post} =
        BlogFixtures.post_attrs(status: :published)
        |> Blog.create_post()

      # make the tag and tag the post
      {:ok, _tag} = Tags.create_tag(%{title: "wallop"})
      {:ok, post} = Tags.tag(post, "wallop")

      # we have one tag
      assert 1 == Repo.aggregate(Tag, :count)

      # and it is on the note
      %{tags: [tag]} = post
      assert tag.title == "wallop"
    end

    test "works with a post and a non-existing tag" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make a post
      {:ok, post} =
        BlogFixtures.post_attrs(status: :published)
        |> Blog.create_post()

      # tag it
      {:ok, post} = Tags.tag(post, "wallop")

      # we have one tag
      assert 1 == Repo.aggregate(Tag, :count)
      #
      # and it is on the note
      %{tags: [tag]} = post
      assert tag.title == "wallop"
    end
  end

  describe "Tags.tag_by_title/1" do
    test "works as expected" do
      # make a tag
      {:ok, _tag} = Tags.create_tag(%{title: "Tag Is A Tag"})

      # and we can get it by title
      {:ok, _tag} = Tags.tag_by_title("Tag Is A Tag")
    end

    test "fails as expected" do
      {:error, :not_found} = Tags.tag_by_title("Nah Fam - no tag here")
    end
  end

  describe "upsert_tag" do
    test "works as expected" do
      # make a tag
      {:ok, tag1} =
        %Tag{}
        |> Tags.changeset_tag(%{title: "Tag Is A Tag"})
        |> Tags.upsert_tag()

      # we have one
      assert 1 == Repo.aggregate(Tag, :count)

      # send it again - still one
      {:ok, tag2} =
        %Tag{}
        |> Tags.changeset_tag(%{title: "Tag Is A Tag"})
        |> Tags.upsert_tag()

      # # we still have one
      assert 1 == Repo.aggregate(Tag, :count)

      # # tags1 and tag2 are the same
      assert tag1.id == tag2.id
    end
  end

  describe "Tags.create_tag/1" do
    test "lowercase tags" do
      # make a tag with mixed case and it normalises to lowercas
      {:ok, tag} = Tags.create_tag(%{title: "Tag Is A Tag"})
      assert 1 == Repo.aggregate(Tag, :count)

      # and tag has a slug and lower case title
      assert tag.title == "tag is a tag"
      assert tag.slug == "tag-is-a-tag"
    end

    test "works as expected" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make a tag and we have one
      {:ok, tag} = Tags.create_tag(%{title: "tagisatag"})
      assert 1 == Repo.aggregate(Tag, :count)

      # and tag has a slug
      assert tag.slug == "tagisatag"
    end

    test "fails as expected" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # tag creation fails, no tags, errors as expected
      changeset = Tags.create_tag(%{title: nil})
      assert 0 == Repo.aggregate(Tag, :count)
      assert 1 == changeset.errors |> length()
    end
  end
end
