defmodule Jamie.BlogOgImageTest do
  use Jamie.DataCase
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Blog
  alias Jamie.Support.BlogFixtures
  alias Jamie.Workers.OgImageCreate

  describe "og image scheduling" do
    test "creating a post enqueues an og image job for that post" do
      {:ok, post} = BlogFixtures.post_attrs() |> Blog.create_post()

      assert_enqueued(worker: OgImageCreate, args: %{thing: "post", id: post.id})
    end

    test "editing a post in a way that changes the og_hash enqueues a fresh job" do
      {:ok, post} = BlogFixtures.post_attrs() |> Blog.create_post()

      {:ok, edited} = Blog.update_post(post, %{"title" => "A brand new title"})

      # The title changed, so the hash changed, so a new job is queued.
      refute edited.og_hash == post.og_hash
      assert_enqueued(worker: OgImageCreate, args: %{thing: "post", id: edited.id})
    end

    test "editing a post without changing title/description does not enqueue a job" do
      {:ok, post} = BlogFixtures.post_attrs() |> Blog.create_post()

      # Creation queues one job; an unrelated edit should not add another.
      before = length(all_enqueued(worker: OgImageCreate))

      {:ok, edited} = Blog.update_post(post, %{"status" => "published"})

      # Status doesn't feed the hash, so the job count is unchanged.
      assert edited.og_hash == post.og_hash
      assert length(all_enqueued(worker: OgImageCreate)) == before
    end
  end
end
