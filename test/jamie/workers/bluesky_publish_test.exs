defmodule Jamie.Workers.BlueskyPublishTest do
  # not async: the standard.site publication uri is cached node-wide
  use Jamie.DataCase, async: false
  use Oban.Testing, repo: Jamie.Repo

  import ExUnit.CaptureLog

  alias Jamie.Bluesky
  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Support.FakeBluesky
  alias Jamie.Support.FakeR2
  alias Jamie.Workers.BlueskyPublish

  setup do
    Bluesky.forget_publication()
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :published))
    {:ok, _} = Jamie.Tags.set_post_tags(post, ["trees", "elixir"])
    FakeR2.put_file("png-bytes", "opengraph/#{post.og_hash}.png")
    Phoenix.PubSub.subscribe(Jamie.PubSub, "post:#{post.id}")
    %{post: post}
  end

  defp publish(post, text \\ "Hello Bluesky") do
    perform_job(BlueskyPublish, %{"action" => "publish", "post_id" => post.id, "text" => text})
  end

  defp records(collection) do
    for opts <- FakeBluesky.calls("com.atproto.repo.createRecord"),
        opts[:json].collection == collection,
        do: opts[:json].record
  end

  describe "publish" do
    test "posts a link card with the opengraph image as its thumbnail", %{post: post} do
      assert :ok = publish(post)

      assert [%{"text" => "Hello Bluesky", "langs" => ["en"], "embed" => embed}] =
               records("app.bsky.feed.post")

      assert embed["$type"] == "app.bsky.embed.external"
      assert embed["external"]["uri"] == JamieWeb.Endpoint.url() <> "/posts/" <> post.slug
      assert embed["external"]["title"] == post.title
      assert embed["external"]["thumb"]["ref"] == %{"$link" => "bafkreitestblob"}

      assert [blob] = FakeBluesky.calls("com.atproto.repo.uploadBlob")
      assert blob[:body] == "png-bytes"
    end

    test "writes a standard.site document under a new publication", %{post: post} do
      assert :ok = publish(post)

      assert [%{"url" => url, "name" => "Jamie Curle"}] = records("site.standard.publication")
      assert url == JamieWeb.Endpoint.url()

      saved = Content.get_post!(post.id)
      assert [document] = records("site.standard.document")
      assert document["site"] =~ "/site.standard.publication/"
      assert document["path"] == "/posts/#{post.slug}"
      assert document["title"] == post.title
      assert document["tags"] == ["elixir", "trees"]
      assert document["bskyPostRef"] == %{"uri" => saved.bluesky_uri, "cid" => saved.bluesky_cid}
      # the plain text has no markup left in it
      assert document["textContent"] =~ "test the thing"
      refute document["textContent"] =~ "<"
    end

    test "saves where it went and tells the editor", %{post: post} do
      assert :ok = publish(post)

      saved = Content.get_post!(post.id)
      assert saved.bluesky_uri =~ "/app.bsky.feed.post/"
      assert saved.bluesky_cid
      assert saved.bluesky_posted_at
      assert saved.standard_document_uri =~ "/site.standard.document/"
      # not an edit, so the editor's conflict check isn't tripped
      assert saved.updated_at == post.updated_at

      assert_received {:post_bluesky, %{standard_document_uri: uri}} when is_binary(uri)
    end

    test "reuses an existing publication", %{post: post} do
      FakeBluesky.put_records("site.standard.publication", [
        %{
          "uri" => "at://did:plc:jamietest/site.standard.publication/existing",
          "value" => %{"url" => JamieWeb.Endpoint.url()}
        }
      ])

      assert :ok = publish(post)
      assert records("site.standard.publication") == []

      assert [%{"site" => "at://did:plc:jamietest/site.standard.publication/existing"}] =
               records("site.standard.document")
    end

    test "goes without a thumbnail when there's no opengraph image", %{post: post} do
      FakeR2.delete_files(["opengraph/#{post.og_hash}.png"])

      assert :ok = publish(post)
      assert [%{"embed" => %{"external" => external}}] = records("app.bsky.feed.post")
      refute Map.has_key?(external, "thumb")
    end

    test "a retry after a part-way failure doesn't post twice", %{post: post} do
      FakeBluesky.respond(
        "com.atproto.repo.listRecords",
        {:ok, %{status: 502, body: %{"error" => "UpstreamFailure"}}}
      )

      capture_log(fn -> assert {:error, _} = publish(post) end)
      assert_received {:bluesky_error, _, "Bluesky said UpstreamFailure."}

      half_done = Content.get_post!(post.id)
      assert half_done.bluesky_uri
      assert is_nil(half_done.standard_document_uri)

      # Bluesky recovers and Oban tries again
      FakeBluesky.respond(
        "com.atproto.repo.listRecords",
        {:ok, %{status: 200, body: %{"records" => []}}}
      )

      assert :ok = publish(half_done)
      assert length(records("app.bsky.feed.post")) == 1
      assert Content.get_post!(post.id).standard_document_uri
    end

    test "a bad app password fails and says why", %{post: post} do
      FakeBluesky.respond(
        "com.atproto.server.createSession",
        {:ok,
         %{status: 401, body: %{"error" => "AuthenticationRequired", "message" => "Bad password"}}}
      )

      capture_log(fn -> assert {:error, _} = publish(post) end)
      assert_received {:bluesky_error, _, "Bluesky said AuthenticationRequired: Bad password"}
      assert is_nil(Content.get_post!(post.id).bluesky_uri)
    end
  end

  describe "remove" do
    test "deletes both records and clears the post", %{post: post} do
      :ok = publish(post)
      published = Content.get_post!(post.id)

      assert :ok = perform_job(BlueskyPublish, %{"action" => "remove", "post_id" => post.id})

      deleted =
        for opts <- FakeBluesky.calls("com.atproto.repo.deleteRecord"), do: opts[:json].rkey

      assert deleted == [
               published.bluesky_uri |> String.split("/") |> List.last(),
               published.standard_document_uri |> String.split("/") |> List.last()
             ]

      cleared = Content.get_post!(post.id)
      assert is_nil(cleared.bluesky_uri)
      assert is_nil(cleared.standard_document_uri)
    end
  end

  describe "Content.publish_to_bluesky/2" do
    test "queues the job", %{post: post} do
      assert {:ok, _job} = Content.publish_to_bluesky(post, "  Hello  ")

      assert_enqueued(
        worker: BlueskyPublish,
        args: %{"action" => "publish", "post_id" => post.id, "text" => "Hello"}
      )
    end

    test "refuses drafts, blank text and text over 300 graphemes", %{post: post} do
      {:ok, draft} =
        Content.create_post(ContentFixtures.post_attrs(status: :draft, title: "A draft"))

      assert {:error, :not_published} = Content.publish_to_bluesky(draft, "Hi")
      assert {:error, :blank} = Content.publish_to_bluesky(post, "   ")

      assert {:error, :too_long} =
               Content.publish_to_bluesky(post, String.duplicate("a", 301))

      refute_enqueued(worker: BlueskyPublish)
    end

    test "refuses a post that is already out", %{post: post} do
      :ok = publish(post)

      assert {:error, :already_published} =
               Content.publish_to_bluesky(Content.get_post!(post.id), "Again")
    end
  end
end
