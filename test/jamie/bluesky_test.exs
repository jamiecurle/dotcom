defmodule Jamie.BlueskyTest do
  # not async: the publication uri is cached node-wide in :persistent_term
  use ExUnit.Case, async: false

  alias Jamie.Bluesky
  alias Jamie.Support.FakeBluesky

  setup do
    Bluesky.forget_publication()
    :ok
  end

  describe "identity" do
    test "resolves the handle to a DID and finds its PDS" do
      assert {:ok, %{did: "did:plc:jamietest", pds: "https://pds.bluesky.test"}} =
               Bluesky.identity()

      assert [[url: url, method: :get]] = FakeBluesky.calls("com.atproto.identity.resolveHandle")
      assert url =~ "handle=jamie.test"
    end

    test "a DID document without a PDS is an error" do
      FakeBluesky.respond(
        "plc:did:plc:jamietest",
        {:ok, %{status: 200, body: %{"service" => []}}}
      )

      assert {:error, :no_pds} = Bluesky.identity()
    end

    # plc.directory answers with application/did+ld+json, which Req leaves
    # as a string; found by trying it against the real directory
    test "a DID document served as a JSON string is decoded" do
      document = %{
        "service" => [%{"id" => "#atproto_pds", "serviceEndpoint" => "https://pds.example"}]
      }

      FakeBluesky.respond(
        "plc:did:plc:jamietest",
        {:ok, %{status: 200, body: Jason.encode!(document)}}
      )

      assert {:ok, %{pds: "https://pds.example"}} = Bluesky.identity()
    end

    test "a reply that isn't the shape asked for is an error, not a value" do
      FakeBluesky.respond("plc:did:plc:jamietest", {:ok, %{status: 200, body: "<html>"}})
      assert {:error, :unexpected_response} = Bluesky.identity()
    end

    test "did:web isn't supported" do
      assert {:error, :unsupported_did} = Bluesky.pds_for("did:web:example.com")
    end
  end

  describe "create_session/0" do
    test "logs in against my PDS with the app password" do
      assert {:ok, session} = Bluesky.create_session()
      assert session == %{did: FakeBluesky.did(), pds: FakeBluesky.pds(), access_jwt: "test-jwt"}

      assert [opts] = FakeBluesky.calls("com.atproto.server.createSession")
      assert opts[:url] == "https://pds.bluesky.test/xrpc/com.atproto.server.createSession"
      assert opts[:json] == %{identifier: "jamie.test", password: "test-app-password"}
    end

    test "a wrong password comes back as an XRPC error" do
      FakeBluesky.respond(
        "com.atproto.server.createSession",
        {:ok,
         %{
           status: 401,
           body: %{"error" => "AuthenticationRequired", "message" => "Invalid password"}
         }}
      )

      assert {:error, {:xrpc, 401, "AuthenticationRequired", "Invalid password"}} =
               Bluesky.create_session()
    end
  end

  describe "writing records" do
    setup do
      {:ok, session} = Bluesky.create_session()
      %{session: session}
    end

    test "create_record/3 stamps the $type and authenticates", %{session: session} do
      assert {:ok, %{uri: "at://did:plc:jamietest/app.bsky.feed.post/" <> _, cid: _}} =
               Bluesky.create_record(session, "app.bsky.feed.post", %{"text" => "hi"})

      assert [opts] = FakeBluesky.calls("com.atproto.repo.createRecord")
      assert opts[:json].repo == "did:plc:jamietest"
      assert opts[:json].record == %{"$type" => "app.bsky.feed.post", "text" => "hi"}
      assert {"authorization", "Bearer test-jwt"} in opts[:headers]
    end

    test "upload_blob/3 sends the bytes with their content type", %{session: session} do
      assert {:ok, %{"$type" => "blob", "mimeType" => "image/png", "size" => 3}} =
               Bluesky.upload_blob(session, "png", "image/png")
    end

    test "delete_record/2 splits the uri into repo, collection and rkey", %{session: session} do
      assert :ok = Bluesky.delete_record(session, "at://did:plc:jamietest/app.bsky.feed.post/3k")

      assert [opts] = FakeBluesky.calls("com.atproto.repo.deleteRecord")

      assert opts[:json] == %{
               repo: "did:plc:jamietest",
               collection: "app.bsky.feed.post",
               rkey: "3k"
             }
    end
  end

  describe "publications" do
    test "ensure_publication/3 creates the record the first time" do
      {:ok, session} = Bluesky.create_session()

      assert {:ok, uri} =
               Bluesky.ensure_publication(session, "https://jamie.test", %{"name" => "Jamie"})

      assert uri =~ "/site.standard.publication/"
      assert [opts] = FakeBluesky.calls("com.atproto.repo.createRecord")
      assert opts[:json].record["url"] == "https://jamie.test"
      assert {:ok, ^uri} = Bluesky.publication_uri("https://jamie.test")
    end

    test "an existing publication is found by url, trailing slash or not" do
      FakeBluesky.put_records("site.standard.publication", [
        %{"uri" => "at://x/site.standard.publication/other", "value" => %{"url" => "https://a"}},
        %{
          "uri" => "at://x/site.standard.publication/mine",
          "value" => %{"url" => "https://jamie.test/"}
        }
      ])

      assert {:ok, "at://x/site.standard.publication/mine"} =
               Bluesky.publication_uri("https://jamie.test")

      assert FakeBluesky.calls("com.atproto.repo.createRecord") == []
    end

    test "a missing publication isn't cached" do
      assert {:error, :not_found} = Bluesky.publication_uri("https://jamie.test")

      FakeBluesky.put_records("site.standard.publication", [
        %{
          "uri" => "at://x/site.standard.publication/new",
          "value" => %{"url" => "https://jamie.test"}
        }
      ])

      assert {:ok, "at://x/site.standard.publication/new"} =
               Bluesky.publication_uri("https://jamie.test")
    end
  end

  describe "post_text/2" do
    test "is the title and description separated by a blank line" do
      assert Bluesky.post_text("Title", "About it") == "Title\n\nAbout it"
      assert Bluesky.post_text("Title", nil) == "Title"
    end

    test "is cut to 300 graphemes, counting an emoji with modifiers as one" do
      # a family emoji is several codepoints and many bytes but one grapheme
      long = String.duplicate("👨‍👩‍👧", 400)
      text = Bluesky.post_text(long, "desc")

      assert String.length(text) == 300
      assert String.ends_with?(text, "…")
    end
  end

  describe "replies/1" do
    test "keeps viewable replies as a tree, oldest first" do
      thread = FakeBluesky.thread("at://p")
      # an older reply arriving later in the list should sort first
      older =
        thread["replies"]
        |> hd()
        |> put_in(["post", "record", "createdAt"], "2026-10-09T08:00:00.000Z")
        |> put_in(["post", "uri"], "at://did:plc:bob/app.bsky.feed.post/3kbob")
        |> put_in(["post", "author", "handle"], "bob.test")
        |> put_in(["post", "author", "displayName"], "")
        |> Map.put("replies", [])

      replies = Bluesky.replies(%{thread | "replies" => thread["replies"] ++ [older]})

      assert [%{name: "bob.test"} = bob, alice] =
               Enum.map(replies, &Map.take(&1, [:name, :replies]))

      assert bob.replies == []
      assert %{name: "Alice", replies: [%{name: "Jamie", text: "Thanks Alice"}]} = alice
    end

    test "a thread with no replies has none" do
      assert Bluesky.replies(%{"post" => %{}}) == []
    end
  end

  test "web_url/1 points at the post on bsky.app" do
    assert Bluesky.web_url("at://did:plc:abc/app.bsky.feed.post/3kxyz") ==
             "https://bsky.app/profile/did:plc:abc/post/3kxyz"
  end

  test "get_thread/1 reads from the public AppView" do
    assert {:ok, %{"post" => %{"uri" => "at://p"}, "replies" => [_, _]}} =
             Bluesky.get_thread("at://p")
  end
end
