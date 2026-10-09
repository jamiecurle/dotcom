defmodule JamieWeb.ContentLive.Post do
  use JamieWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, assign_post(socket, post)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    socket =
      with post <- Jamie.Content.get_post_by_slug!(slug, socket.assigns.current_scope),
           og_image <- og_image(post) do
        # do the pubsub
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jamie.PubSub, "post:#{post.id}")
        end

        socket
        |> assign(:body_id, "post")
        |> assign_post(post)
        |> assign(:more_posts, more_posts(post))
        |> assign(:page_title, post.title)
        |> assign(:page_description, post.description)
        |> assign(:og_type, "article")
        |> assign(:og_image, og_image)
      end

    {:noreply, socket}
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
