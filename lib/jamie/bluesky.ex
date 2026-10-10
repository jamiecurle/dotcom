defmodule Jamie.Bluesky do
  @moduledoc """
  A small AT Protocol client: just enough XRPC to publish posts to my
  Bluesky account and read the replies back.

  How the pieces fit:

    * my account is a signed repository of records on a PDS (Bluesky's own,
      for now). Writing an `app.bsky.feed.post` record into it *is* posting.
    * the PDS is found from my handle: handle -> DID (resolveHandle on the
      public AppView) -> DID document (plc.directory) -> PDS endpoint. Nothing
      here hardcodes bsky.social, so moving to my own PDS later needs no code.
    * writes need a session, made from the handle and an app password.
      Sessions are cheap and publishing is rare, so a new one is made for
      each publish rather than storing and refreshing tokens.
    * reads (listRecords on the PDS, getPostThread on the AppView) are public.

  Every call goes through the `:bluesky` service (Req in dev and prod,
  `Jamie.Support.FakeBluesky` in test) and returns `{:ok, body}` or
  `{:error, reason}`.
  """

  alias Jamie.Service

  # Bluesky post text is capped at 300 graphemes, not bytes or codepoints
  @max_graphemes 300

  @publication_key {__MODULE__, :publication_uri}

  @doc """
  True when both the handle and app password are set, i.e. we can write.
  """
  def configured? do
    config = config()
    present?(config[:handle]) and present?(config[:app_password])
  end

  @doc """
  The handle posts are published as, e.g. "curle.io".
  """
  def handle, do: config()[:handle]

  ## Identity

  @doc """
  Resolves a handle to its DID using the public AppView.
  """
  def resolve_handle(handle) do
    case get(config()[:appview], "com.atproto.identity.resolveHandle", handle: handle) do
      {:ok, %{"did" => did}} -> {:ok, did}
      other -> unexpected(other)
    end
  end

  @doc """
  Finds the PDS that hosts a DID by reading its DID document from the PLC
  directory. (did:web identities aren't supported; mine is did:plc.)
  """
  def pds_for("did:plc:" <> _ = did) do
    case request(:get, config()[:plc] <> "/" <> did) do
      {:ok, %{"service" => services}} ->
        case Enum.find(services, &(&1["id"] == "#atproto_pds")) do
          %{"serviceEndpoint" => endpoint} -> {:ok, endpoint}
          nil -> {:error, :no_pds}
        end

      other ->
        unexpected(other)
    end
  end

  def pds_for(_did), do: {:error, :unsupported_did}

  @doc """
  The DID and PDS for the configured handle.
  """
  def identity do
    with {:ok, did} <- resolve_handle(handle()),
         {:ok, pds} <- pds_for(did) do
      {:ok, %{did: did, pds: pds}}
    end
  end

  ## Writing

  @doc """
  Logs in with the app password. The session carries everything a write
  needs: the PDS to send it to, the repo (DID) and the bearer token.
  """
  def create_session do
    if configured?() do
      with {:ok, %{did: did, pds: pds}} <- identity(),
           {:ok, %{"accessJwt" => jwt}} <-
             request(:post, xrpc(pds, "com.atproto.server.createSession"),
               json: %{identifier: handle(), password: config()[:app_password]}
             ) do
        {:ok, %{did: did, pds: pds, access_jwt: jwt}}
      else
        other -> unexpected(other)
      end
    else
      {:error, :not_configured}
    end
  end

  @doc """
  Uploads an image and returns the blob reference to embed in a record.
  A blob only sticks around if a record points at it.
  """
  def upload_blob(session, binary, mime_type) do
    :post
    |> request(xrpc(session.pds, "com.atproto.repo.uploadBlob"),
      body: binary,
      headers: [auth(session), {"content-type", mime_type}]
    )
    |> case do
      {:ok, %{"blob" => blob}} -> {:ok, blob}
      other -> unexpected(other)
    end
  end

  @doc """
  Writes a record into my repo, returning its `at://` uri and cid.
  """
  def create_record(session, collection, record) do
    :post
    |> request(xrpc(session.pds, "com.atproto.repo.createRecord"),
      json: %{
        repo: session.did,
        collection: collection,
        record: Map.put(record, "$type", collection)
      },
      headers: [auth(session)]
    )
    |> case do
      {:ok, %{"uri" => uri, "cid" => cid}} -> {:ok, %{uri: uri, cid: cid}}
      other -> unexpected(other)
    end
  end

  @doc """
  Deletes the record at an `at://` uri. Deleting something already gone
  is fine as far as the PDS is concerned.
  """
  def delete_record(session, uri) do
    {:ok, %{repo: repo, collection: collection, rkey: rkey}} = parse_uri(uri)

    with {:ok, _} <-
           request(:post, xrpc(session.pds, "com.atproto.repo.deleteRecord"),
             json: %{repo: repo, collection: collection, rkey: rkey},
             headers: [auth(session)]
           ) do
      :ok
    end
  end

  ## Reading

  @doc """
  Lists the records in one collection of a repo. Public; no session needed.
  One page of 100 is plenty for the collections read here.
  """
  def list_records(pds, did, collection) do
    case get(pds, "com.atproto.repo.listRecords", repo: did, collection: collection, limit: 100) do
      {:ok, %{"records" => records}} -> {:ok, records}
      other -> unexpected(other)
    end
  end

  @doc """
  Fetches a post and its replies from the public AppView.
  """
  def get_thread(uri) do
    case get(config()[:appview], "app.bsky.feed.getPostThread", uri: uri, depth: 6) do
      {:ok, %{"thread" => thread}} -> {:ok, thread}
      other -> unexpected(other)
    end
  end

  @doc """
  The replies in a thread from `get_thread/1` as a plain tree, oldest
  first at each level, ready for a template:

      [%{uri:, url:, handle:, name:, text:, created_at:, replies: [...]}]

  Deleted, blocked and otherwise unviewable replies are left out.
  """
  def replies(%{"replies" => replies}) when is_list(replies) do
    replies
    |> Enum.filter(&(&1["$type"] == "app.bsky.feed.defs#threadViewPost"))
    |> Enum.map(&reply/1)
    |> Enum.sort_by(& &1.created_at, DateTime)
  end

  def replies(_thread), do: []

  defp reply(%{"post" => post} = view) do
    author = post["author"]

    created_at =
      case DateTime.from_iso8601(post["record"]["createdAt"] || "") do
        {:ok, datetime, _offset} -> datetime
        _ -> DateTime.from_unix!(0)
      end

    %{
      uri: post["uri"],
      url: web_url(post["uri"]),
      handle: author["handle"],
      name: present_or(author["displayName"], author["handle"]),
      text: post["record"]["text"] || "",
      created_at: created_at,
      replies: replies(view)
    }
  end

  defp present_or(value, fallback), do: if(present?(value), do: value, else: fallback)

  ## standard.site

  @doc """
  The `at://` uri of the site.standard.publication record for this site,
  looked up in my repo by its url. Found once and then remembered for the
  life of the node; a miss isn't remembered, so it shows up as soon as the
  first publish creates it.
  """
  def publication_uri(site_url) do
    case :persistent_term.get(@publication_key, nil) do
      nil ->
        with {:ok, %{did: did, pds: pds}} <- identity(),
             {:ok, uri} <- find_publication(pds, did, site_url) do
          remember_publication(uri)
        end

      uri ->
        {:ok, uri}
    end
  end

  @doc """
  Finds this site's publication record, creating it on first use.
  """
  def ensure_publication(session, site_url, attrs) do
    case find_publication(session.pds, session.did, site_url) do
      {:ok, uri} ->
        remember_publication(uri)

      {:error, :not_found} ->
        with {:ok, %{uri: uri}} <-
               create_record(
                 session,
                 "site.standard.publication",
                 Map.put(attrs, "url", site_url)
               ) do
          remember_publication(uri)
        end

      error ->
        error
    end
  end

  @doc false
  # for tests, which share the one node-wide cache
  def forget_publication, do: :persistent_term.erase(@publication_key)

  defp find_publication(pds, did, site_url) do
    with {:ok, records} <- list_records(pds, did, "site.standard.publication") do
      case Enum.find(records, &(trim_slash(&1["value"]["url"]) == trim_slash(site_url))) do
        %{"uri" => uri} -> {:ok, uri}
        nil -> {:error, :not_found}
      end
    end
  end

  defp remember_publication(uri) do
    :persistent_term.put(@publication_key, uri)
    {:ok, uri}
  end

  defp trim_slash(nil), do: nil
  defp trim_slash(url), do: String.trim_trailing(url, "/")

  ## Helpers

  @doc """
  The text of the Bluesky post announcing a blog post: the title, a blank
  line, then the description, cut to fit Bluesky's 300 grapheme limit.
  The link itself rides along in the card, so it isn't in the text.
  """
  def post_text(title, description) do
    [title, description]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> Enum.join("\n\n")
    |> truncate()
  end

  @doc """
  Cuts text to Bluesky's limit, ending with an ellipsis when it had to cut.
  """
  def truncate(text, max \\ @max_graphemes) do
    if String.length(text) <= max do
      text
    else
      String.slice(text, 0, max - 1) <> "…"
    end
  end

  @doc "The most graphemes a Bluesky post may hold."
  def max_graphemes, do: @max_graphemes

  @doc """
  Splits an `at://repo/collection/rkey` uri into its parts.
  """
  def parse_uri("at://" <> rest) do
    case String.split(rest, "/") do
      [repo, collection, rkey] -> {:ok, %{repo: repo, collection: collection, rkey: rkey}}
      _ -> {:error, :invalid_uri}
    end
  end

  def parse_uri(_), do: {:error, :invalid_uri}

  @doc """
  The bsky.app address for a post's `at://` uri, for "view on Bluesky" links.
  """
  def web_url(uri) do
    {:ok, %{repo: repo, rkey: rkey}} = parse_uri(uri)
    "https://bsky.app/profile/#{repo}/post/#{rkey}"
  end

  defp xrpc(host, method), do: host <> "/xrpc/" <> method

  # query strings go into the url itself, so the test fake can match on it
  defp get(host, method, query) do
    request(:get, xrpc(host, method) <> "?" <> URI.encode_query(query))
  end

  defp auth(session), do: {"authorization", "Bearer " <> session.access_jwt}

  defp request(method, url, opts \\ []) do
    http = Service.get!(:bluesky)

    case http.request([url: url, method: method] ++ opts) do
      {:ok, %{status: status, body: body}} -> response(status, decode(body))
      {:error, reason} -> {:error, reason}
    end
  end

  defp response(status, body) when status in 200..299, do: {:ok, body}

  # XRPC errors come back as {"error": "...", "message": "..."}
  defp response(status, %{"error" => error} = body),
    do: {:error, {:xrpc, status, error, body["message"]}}

  defp response(status, _body), do: {:error, {:http, status}}

  # Req decodes application/json bodies itself, but plc.directory answers
  # with application/did+ld+json, which it leaves as a string
  defp decode(body) when is_binary(body) do
    case Jason.decode(body) do
      {:ok, decoded} -> decoded
      {:error, _} -> body
    end
  end

  defp decode(body), do: body

  # a 2xx whose body isn't the shape asked for is as good as a failure
  defp unexpected({:ok, _body}), do: {:error, :unexpected_response}
  defp unexpected(error), do: error

  defp config, do: Application.get_env(:jamie, :bluesky, [])

  defp present?(value), do: is_binary(value) and value != ""
end
