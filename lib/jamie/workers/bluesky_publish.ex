defmodule Jamie.Workers.BlueskyPublish do
  @moduledoc """
  Puts a post onto the AT Protocol, or takes it off again.

  Publishing writes two records into my repo:

    1. an `app.bsky.feed.post` announcing it, with a link card (title,
       description and the opengraph image as the thumbnail). This is what
       shows up on Bluesky.
    2. a `site.standard.document` (https://standard.site) holding the post
       itself, pointing back at the announcement so readers that understand
       the lexicon can find the conversation.

  Each step saves its result on the post as soon as it lands, and skips
  itself when the post already has one, so a retry after a failure part way
  through carries on rather than posting twice.

  Removing deletes both records and clears the post's fields.
  """
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 60, keys: [:post_id, :action], states: :incomplete]

  require Logger

  alias Jamie.Bluesky
  alias Jamie.Content
  alias Jamie.Content.Post
  alias Jamie.Service

  @r2 Service.get!(:r2)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"action" => "publish", "post_id" => id, "text" => text}} = job) do
    post = Content.get_post!(id)

    with {:ok, session} <- Bluesky.create_session(),
         {:ok, thumb} <- thumbnail(session, post),
         {:ok, post} <- announce(session, post, text, thumb),
         {:ok, _post} <- document(session, post, thumb) do
      Logger.info("Oban: success: published post:#{id} to Bluesky")
      :ok
    else
      error -> failed(job, post, error)
    end
  end

  def perform(%Oban.Job{args: %{"action" => "remove", "post_id" => id}} = job) do
    post = Content.get_post!(id)

    with {:ok, session} <- Bluesky.create_session(),
         :ok <- delete(session, post.bluesky_uri),
         :ok <- delete(session, post.standard_document_uri),
         {:ok, _post} <-
           Content.put_post_bluesky(post, %{
             bluesky_uri: nil,
             bluesky_cid: nil,
             bluesky_posted_at: nil,
             standard_document_uri: nil
           }) do
      Logger.info("Oban: success: removed post:#{id} from Bluesky")
      :ok
    else
      error -> failed(job, post, error)
    end
  end

  # The opengraph image makes the link card's thumbnail and the document's
  # cover. It's a nice-to-have: without one the card is just text.
  defp thumbnail(_session, %Post{og_hash: nil}), do: {:ok, nil}

  defp thumbnail(session, %Post{og_hash: og_hash}) do
    case @r2.get_file("opengraph/#{og_hash}.png") do
      {:ok, %{body: png}} -> Bluesky.upload_blob(session, png, "image/png")
      {:error, _} -> {:ok, nil}
    end
  end

  defp announce(_session, %Post{bluesky_uri: uri} = post, _text, _thumb) when is_binary(uri),
    do: {:ok, post}

  defp announce(session, post, text, thumb) do
    external =
      %{"uri" => post_url(post), "title" => post.title, "description" => post.description || ""}
      |> put_if("thumb", thumb)

    record = %{
      "text" => text,
      "createdAt" => DateTime.to_iso8601(DateTime.utc_now()),
      "langs" => ["en"],
      "embed" => %{"$type" => "app.bsky.embed.external", "external" => external}
    }

    with {:ok, %{uri: uri, cid: cid}} <-
           Bluesky.create_record(session, "app.bsky.feed.post", record) do
      Content.put_post_bluesky(post, %{
        bluesky_uri: uri,
        bluesky_cid: cid,
        bluesky_posted_at: DateTime.utc_now()
      })
    end
  end

  defp document(_session, %Post{standard_document_uri: uri} = post, _thumb) when is_binary(uri),
    do: {:ok, post}

  defp document(session, post, thumb) do
    record =
      %{
        "path" => "/posts/#{post.slug}",
        "title" => post.title,
        "description" => post.description,
        "publishedAt" => published_at(post),
        "textContent" => plain_text(post.html),
        "tags" => Jamie.Tags.post_tag_titles(post),
        "bskyPostRef" => %{"uri" => post.bluesky_uri, "cid" => post.bluesky_cid}
      }
      |> put_if("coverImage", thumb)

    with {:ok, publication} <-
           Bluesky.ensure_publication(session, site_url(), %{
             "name" => "Jamie Curle",
             "description" =>
               "Writing about tech, software, trees, woodland and stuff from the workshop."
           }),
         {:ok, %{uri: uri}} <-
           Bluesky.create_record(
             session,
             "site.standard.document",
             Map.put(record, "site", publication)
           ) do
      Content.put_post_bluesky(post, %{standard_document_uri: uri})
    end
  end

  defp delete(_session, nil), do: :ok
  defp delete(session, uri), do: Bluesky.delete_record(session, uri)

  # Tell the editor what went wrong, then let Oban retry. Not being set up
  # won't fix itself, so that one cancels instead.
  defp failed(job, post, error) do
    Logger.error("Oban: error: Bluesky #{job.args["action"]} post:#{post.id} #{inspect(error)}")
    Content.broadcast_bluesky_error(post, describe(error))

    case error do
      {:error, :not_configured} -> {:cancel, :not_configured}
      {:error, reason} -> {:error, reason}
    end
  end

  defp describe({:error, :not_configured}), do: "Bluesky isn't set up on this server."
  defp describe({:error, {:xrpc, _status, error, nil}}), do: "Bluesky said #{error}."
  defp describe({:error, {:xrpc, _status, error, msg}}), do: "Bluesky said #{error}: #{msg}"
  defp describe({:error, reason}), do: "Couldn't reach Bluesky (#{inspect(reason)})."

  defp put_if(map, _key, nil), do: map
  defp put_if(map, key, value), do: Map.put(map, key, value)

  defp site_url, do: JamieWeb.Endpoint.url()
  defp post_url(post), do: site_url() <> "/posts/" <> post.slug

  defp published_at(%Post{published_on: nil}), do: DateTime.to_iso8601(DateTime.utc_now())

  defp published_at(%Post{published_on: date}),
    do: date |> DateTime.new!(~T[00:00:00], "Etc/UTC") |> DateTime.to_iso8601()

  # The document's plain text: the rendered post with its tags stripped,
  # entities decoded and whitespace tidied. Good enough for search and
  # previews, which is all the field is for.
  defp plain_text(nil), do: nil

  defp plain_text(html) do
    html
    |> String.replace(~r/<(script|style)[^>]*>.*?<\/\1>/s, "")
    |> String.replace(~r/<\/(p|h[1-6]|li|pre|blockquote|tr)>|<br\s*\/?>/, "\n")
    |> String.replace(~r/<[^>]+>/, "")
    |> String.replace(["&amp;", "&lt;", "&gt;", "&quot;", "&#39;", "&nbsp;"], fn
      "&amp;" -> "&"
      "&lt;" -> "<"
      "&gt;" -> ">"
      "&quot;" -> "\""
      "&#39;" -> "'"
      "&nbsp;" -> " "
    end)
    |> String.replace(~r/[ \t]+/, " ")
    |> String.replace(~r/\n\s*\n+/, "\n\n")
    |> String.trim()
  end
end
