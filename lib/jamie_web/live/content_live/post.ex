defmodule JamieWeb.ContentLive.Post do
  use JamieWeb, :live_view

  alias Jamie.Bluesky

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, assign_post(socket, post)}
  end

  # the post just went out to (or came off) Bluesky: fetch the conversation
  def handle_info({:post_bluesky, post}, socket) do
    {:noreply, socket |> assign_post(post) |> fetch_replies()}
  end

  def handle_info({:bluesky_error, _post_id, _message}, socket), do: {:noreply, socket}

  @impl true
  # `?preview=true` is how the post editor's preview pane loads the page; the
  # edit button is hidden there, since it would only open the editor again
  # inside its own preview.
  def handle_params(%{"slug" => slug} = params, _url, socket) do
    socket =
      with post <- Jamie.Content.get_post_by_slug!(slug, socket.assigns.current_scope),
           og_image <- og_image(post) do
        # do the pubsub
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jamie.PubSub, "post:#{post.id}")
        end

        socket
        |> assign(:body_id, "post")
        |> assign(:preview?, params["preview"] == "true")
        |> assign_post(post)
        |> assign(:more_posts, more_posts(post))
        |> assign(:page_title, post.title)
        |> assign(:page_description, post.description)
        |> assign(:og_type, "article")
        |> assign(:og_image, og_image)
        |> assign(:standard_document_uri, post.standard_document_uri)
        |> fetch_replies()
      end

    {:noreply, socket}
  end

  # Replies come from the public Bluesky AppView once the page is live. Doing
  # it after connecting keeps the first render fast and means crawlers, which
  # don't run the socket, never cause a call to Bluesky.
  defp fetch_replies(%{assigns: %{post: %{bluesky_uri: uri}}} = socket)
       when is_binary(uri) do
    socket = assign(socket, :replies, :loading)

    if connected?(socket) do
      start_async(socket, :replies, fn -> Bluesky.get_thread(uri) end)
    else
      socket
    end
  end

  defp fetch_replies(socket), do: assign(socket, :replies, nil)

  @impl true
  def handle_async(:replies, {:ok, {:ok, thread}}, socket) do
    {:noreply, assign(socket, :replies, Bluesky.replies(thread))}
  end

  # Bluesky being away shouldn't spoil the post; the link to reply stays
  def handle_async(:replies, _failed, socket) do
    {:noreply, assign(socket, :replies, :unavailable)}
  end

  # Everything derived from the post body, kept together so a live update
  # (an edit saved elsewhere) refreshes the contents, reading time and tags.
  defp assign_post(socket, post) do
    socket
    |> assign(:post, post)
    |> assign(:toc, Jamie.Markdown.toc(post.markdown))
    |> assign(:reading_minutes, Jamie.Markdown.reading_minutes(post.markdown))
    |> assign(:tags, Jamie.Tags.post_tags(post))
  end

  attr :replies, :list, required: true

  # one level of the conversation; each reply carries its own replies, drawn
  # the same way one step in
  defp replies(assigns) do
    ~H"""
    <ol class="replies">
      <li :for={reply <- @replies} id={"reply-" <> reply_id(reply.uri)}>
        <a href={reply.url} class="reply-byline" target="_blank" rel="noopener">
          <span class="reply-name">{reply.name}</span>
          <span class="reply-handle">@{reply.handle}</span>
          <time datetime={DateTime.to_iso8601(reply.created_at)}>
            {Calendar.strftime(reply.created_at, "%-d %b %Y")}
          </time>
        </a>
        <p class="reply-text">{reply.text}</p>
        <.replies :if={reply.replies != []} replies={reply.replies} />
      </li>
    </ol>
    """
  end

  # every reply at every depth
  defp reply_count(replies) do
    Enum.reduce(replies, 0, fn reply, total -> total + 1 + reply_count(reply.replies) end)
  end

  # a DOM id from an at:// uri: the author and record key are unique enough
  defp reply_id(uri) do
    {:ok, %{repo: repo, rkey: rkey}} = Bluesky.parse_uri(uri)
    String.replace(repo, ":", "-") <> "-" <> rkey
  end

  # A few other recent posts for the end of the page.
  defp more_posts(post) do
    4
    |> Jamie.Content.latest_published_posts()
    |> Enum.reject(&(&1.id == post.id))
    |> Enum.take(3)
  end

  defp og_image(post) do
    case post.og_hash do
      nil ->
        ""

      og_hash ->
        "https://" <>
          Application.get_env(:jamie, :images)[:host] <> "/opengraph/" <> og_hash <> ".png"
    end
  end
end
