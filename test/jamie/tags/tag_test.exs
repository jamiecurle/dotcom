defmodule Jamie.Tags.Test do
  use Jamie.DataCase

  alias Jamie.Repo
  alias Jamie.Tags
  alias Jamie.Tags.Tag

  describe "Tags.create_tag/1" do
    test "works as expected" do
      # there are no tags
      assert 0 == Repo.aggregate(Tag, :count)

      # make a tag and we have one
      {:ok, _tag} = Tags.create_tag(%{title: "tagisatag"})
      assert 1 == Repo.aggregate(Tag, :count)
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
