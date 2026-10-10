defmodule Jamie.Support.FakeBluesky do
  @moduledoc """
  A stand-in for Req when talking to the AT Protocol, injected via the
  `:bluesky` service in test config.

  It plays every part of the network at once, routed by host and XRPC
  method: the AppView (appview.bluesky.test), the PLC directory
  (plc.bluesky.test) and my PDS (pds.bluesky.test). The happy path needs
  no setup.

  Like FakeR2 it keeps state in the process dictionary, so it is isolated
  per test and does NOT cross process boundaries:

    * every request is recorded; `calls/0` returns them in order
    * `respond/2` overrides the answer for one XRPC method, e.g. to fail
    * `put_records/2` sets what listRecords returns for a collection
  """

  @did "did:plc:jamietest"
  @pds "https://pds.bluesky.test"

  @calls :fake_bluesky_calls
  @responses :fake_bluesky_responses
  @records :fake_bluesky_records

  def did, do: @did
  def pds, do: @pds

  @doc "The requests made so far, oldest first, as {xrpc_method, opts}."
  def calls, do: Process.get(@calls, []) |> Enum.reverse()

  @doc "The requests made to one XRPC method, oldest first."
  def calls(method), do: for({^method, opts} <- calls(), do: opts)

  @doc "Answer `method` with `response` ({:ok, %{status, body}} or {:error, _})."
  def respond(method, response) do
    Process.put(@responses, Map.put(Process.get(@responses, %{}), method, response))
  end

  @doc "What listRecords returns for `collection`."
  def put_records(collection, records) do
    Process.put(@records, Map.put(Process.get(@records, %{}), collection, records))
  end

  def request(opts) do
    uri = URI.parse(opts[:url])
    method = xrpc_method(uri)
    Process.put(@calls, [{method, opts} | Process.get(@calls, [])])

    case Process.get(@responses, %{}) do
      %{^method => response} -> response
      _ -> {:ok, %{status: 200, body: answer(method, uri, opts)}}
    end
  end

  defp xrpc_method(%URI{path: "/xrpc/" <> method}), do: method
  defp xrpc_method(%URI{path: "/" <> did}), do: "plc:" <> did

  defp answer("com.atproto.identity.resolveHandle", _uri, _opts), do: %{"did" => @did}

  defp answer("plc:" <> @did, _uri, _opts) do
    %{
      "id" => @did,
      "service" => [
        %{
          "id" => "#atproto_pds",
          "type" => "AtprotoPersonalDataServer",
          "serviceEndpoint" => @pds
        }
      ]
    }
  end

  defp answer("com.atproto.server.createSession", _uri, _opts) do
    %{"did" => @did, "handle" => "jamie.test", "accessJwt" => "test-jwt"}
  end

  defp answer("com.atproto.repo.uploadBlob", _uri, opts) do
    %{
      "blob" => %{
        "$type" => "blob",
        "ref" => %{"$link" => "bafkreitestblob"},
        "mimeType" => header(opts, "content-type"),
        "size" => byte_size(opts[:body])
      }
    }
  end

  # uris are numbered by how many records have been made, so they're unique
  defp answer("com.atproto.repo.createRecord", _uri, opts) do
    collection = opts[:json].collection
    n = length(calls("com.atproto.repo.createRecord"))
    %{"uri" => "at://#{@did}/#{collection}/3ktest#{n}", "cid" => "bafytest#{n}"}
  end

  defp answer("com.atproto.repo.deleteRecord", _uri, _opts), do: %{}

  defp answer("com.atproto.repo.listRecords", uri, _opts) do
    collection = URI.decode_query(uri.query)["collection"]
    %{"records" => Map.get(Process.get(@records, %{}), collection, [])}
  end

  defp answer("app.bsky.feed.getPostThread", uri, _opts) do
    %{"thread" => thread(URI.decode_query(uri.query)["uri"]), "threadgate" => threadgate()}
  end

  defp header(opts, name) do
    Enum.find_value(opts[:headers] || [], fn {key, value} -> key == name && value end)
  end

  @carol "at://did:plc:carol/app.bsky.feed.post/3kcarol"

  @doc "The threadgate on the thread: I hid Carol's reply on Bluesky."
  def threadgate do
    %{
      "uri" => "at://#{@did}/app.bsky.feed.threadgate/3kpost",
      "record" => %{"$type" => "app.bsky.feed.threadgate", "hiddenReplies" => [@carol]}
    }
  end

  @doc """
  A thread like the AppView returns: the post, one reply with its own
  reply, a reply that has since been deleted, one I hid on Bluesky and one
  labelled as spam.
  """
  def thread(uri) do
    %{
      "$type" => "app.bsky.feed.defs#threadViewPost",
      "post" => post_view(uri, "jamie.test", "Jamie", "The announcement"),
      "replies" => [
        %{
          "$type" => "app.bsky.feed.defs#threadViewPost",
          "post" =>
            post_view(
              "at://did:plc:alice/app.bsky.feed.post/3kalice",
              "alice.test",
              "Alice",
              "Lovely post!"
            ),
          "replies" => [
            %{
              "$type" => "app.bsky.feed.defs#threadViewPost",
              "post" =>
                post_view(
                  "at://#{@did}/app.bsky.feed.post/3kreply",
                  "jamie.test",
                  "Jamie",
                  "Thanks Alice"
                ),
              "replies" => []
            }
          ]
        },
        %{"$type" => "app.bsky.feed.defs#notFoundPost", "uri" => "at://gone", "notFound" => true},
        # hidden on Bluesky through the threadgate
        %{
          "$type" => "app.bsky.feed.defs#threadViewPost",
          "post" => post_view(@carol, "carol.test", "Carol", "Off topic"),
          "replies" => []
        },
        # labelled spam by Bluesky's moderation
        %{
          "$type" => "app.bsky.feed.defs#threadViewPost",
          "post" =>
            "at://did:plc:spam/app.bsky.feed.post/3kspam"
            |> post_view("spam.test", "Spammer", "Buy now")
            |> Map.put("labels", [%{"val" => "spam", "src" => "did:plc:moderation"}]),
          "replies" => []
        }
      ]
    }
  end

  defp post_view(uri, handle, display_name, text) do
    %{
      "uri" => uri,
      "cid" => "bafy" <> handle,
      "author" => %{
        "did" => "did:plc:" <> handle,
        "handle" => handle,
        "displayName" => display_name,
        "avatar" => "https://cdn.bluesky.test/#{handle}.jpg"
      },
      "record" => %{
        "$type" => "app.bsky.feed.post",
        "text" => text,
        "createdAt" => "2026-10-10T12:00:00.000Z"
      },
      "indexedAt" => "2026-10-10T12:00:01.000Z",
      "replyCount" => 0,
      "likeCount" => 2
    }
  end
end
