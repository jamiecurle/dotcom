defmodule Jamie.Workers.BookmarkAssetTest do
  use Jamie.DataCase
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Support.ContentFixtures
  alias Jamie.Workers.BookmarkAssets

  describe "happypath" do
    test "works as expected" do
      # build a bookmark
      bookmark =
        ContentFixtures.bookmark_fixture(%{
          favicon: "https://foo.io/favicon.png",
          preview: "https://foo.io/preview.png"
        })

      # build the args
      args =
        %{
          "favicon_src" => bookmark.favicon,
          "favicon" => "/bookmarks/#{bookmark.id}/favicon.png",
          "preview_src" => bookmark.preview,
          "preview" => "/bookmarks/#{bookmark.id}/preview.png"
        }

      # fire the job off
      perform_job(BookmarkAssets, args)

      # the fake_req library has the files in it's backend
      # and they match the destination from the args
    end
  end
end
