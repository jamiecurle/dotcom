defmodule JamieWeb.BlogLive.Post do
  use JamieWeb, :live_view
  # import JamieWeb.BlogComponents

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_info({:post_updated, post}, socket) do
    {:noreply, assign(socket, :post, post)}
  end

  @impl true
  def handle_params(%{"slug" => slug}, _url, socket) do
    socket =
      with post <- Jamie.Blog.get_post_by_slug!(slug, socket.assigns.current_scope) do
        # do the pubsub
        if connected?(socket) do
          Phoenix.PubSub.subscribe(Jamie.PubSub, "post:#{post.id}")
        end

        socket
        |> assign(:body_id, "post")
        |> assign(:post, post)
        |> assign(:toc, toc(post.markdown))
        |> assign(:page_title, post.title)
        |> assign(:page_description, post.description)
        |> assign(:og_type, "article")
      end

    {:noreply, socket}
  end

  # NOTE: you may come back to the TOC stuff so you decided to leave it
  #       in - saves you having to go and do it again.
  defp toc(markdown) do
    {:ok, doc} = MDEx.parse_document(markdown)

    doc
    |> Enum.reduce([], fn
      %MDEx.Heading{level: level, nodes: children}, acc ->
        text = extract_text(children)
        anchor = slugify(text)
        [{level, text, anchor} | acc]

      _node, acc ->
        acc
    end)
    |> Enum.reverse()
  end

  defp extract_text(nodes) do
    Enum.map_join(nodes, fn
      %MDEx.Text{literal: text} -> text
      %MDEx.Code{literal: text} -> text
      %{nodes: children} -> extract_text(children)
      _ -> ""
    end)
  end

  defp slugify(text) do
    text
    |> String.downcase()
    |> String.replace(~r/[^\w\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
