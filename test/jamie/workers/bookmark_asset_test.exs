defmodule Jamie.Workers.BookmarkAssetTest do
  use Jamie.DataCase
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Service
  alias Jamie.Support.ContentFixtures
  alias Jamie.Workers.BookmarkAssets

  @storage Service.get!(:r2)

  describe "happypath" do
    test "works as expected" do
      # build a bookmark
      {:ok, bookmark} =
        ContentFixtures.bookmark_fixture(%{
          favicon: "https://foo.io/favicon.png",
          preview: "https://foo.io/preview.png"
        })

      # build the args
      args =
        %{
          "favicon_src" => bookmark.favicon,
          "favicon_dest" => "/bookmarks/#{bookmark.id}/favicon.png",
          "preview_src" => bookmark.preview,
          "preview_dest" => "/bookmarks/#{bookmark.id}/preview.png"
        }

      # fire the job off
      perform_job(BookmarkAssets, args)

      # and now we have both keys in the storage
      {:ok, %{body: %{contents: files}}} = @storage.list_files()

      assert files == [
               %{key: "/bookmarks/#{bookmark.id}/favicon.png"},
               %{key: "/bookmarks/#{bookmark.id}/preview.png"}
             ]
    end
  end
end
