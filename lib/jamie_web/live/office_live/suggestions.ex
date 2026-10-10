defmodule JamieWeb.OfficeLive.Suggestions do
  @moduledoc """
  The review queue for edits Claude has suggested over MCP. Nothing reaches a
  post until it is accepted here, and accepting goes through the normal
  `update_post` path so it is recorded as a revision.
  """
  use JamieWeb, :live_view

  alias Jamie.Content

  # how much of the surrounding post to show either side of the change
  @context_chars 160

  # `?post_id=` narrows the queue to one post, and `?embed=true` drops the
  # office navbar - together they make the editing-mode side pane of the post
  # editor, which shows this page in an iframe beside the draft.
  @impl true
  def mount(params, _session, socket) do
    # New suggestions are pushed here as Claude files them, and ones resolved
    # in another tab drop out, so two tabs can never act on the same one.
    if connected?(socket), do: Content.subscribe_suggestions()

    post_id = parse_id(params["post_id"])
    filters = if post_id, do: [status: :pending, post_id: post_id], else: [status: :pending]
    suggestions = Content.list_suggestions(socket.assigns.current_scope, filters)

    {:ok,
     socket
     |> assign(post_id: post_id, embed: params["embed"] == "true")
     |> stream(:suggestions, suggestions)}
  end

  defp parse_id(nil), do: nil

  defp parse_id(id) do
    case Integer.parse(id) do
      {id, ""} -> id
      _ -> nil
    end
  end

  @impl true
  def handle_event("accept", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Content.accept_suggestion(scope, String.to_integer(id)) do
      {:ok, suggestion} ->
        {:noreply,
         socket
         |> put_flash(:info, "Applied to “#{suggestion.post.title}”.")
         |> stream_delete(:suggestions, suggestion)}

      {:error, :stale} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "The post has changed since this was suggested, so it was marked stale."
         )
         |> stream_delete(:suggestions, Content.get_suggestion!(scope, id))}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Couldn't apply that suggestion. Try reloading.")}
    end
  end

  def handle_event("reject", %{"id" => id}, socket) do
    scope = socket.assigns.current_scope

    case Content.reject_suggestion(scope, String.to_integer(id)) do
      {:ok, suggestion} ->
        {:noreply, stream_delete(socket, :suggestions, suggestion)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Couldn't reject that suggestion.")}
    end
  end

  @impl true
  def handle_info({:suggestion_created, suggestion}, socket) do
    # a pane narrowed to one post ignores suggestions for any other
    if socket.assigns.post_id in [nil, suggestion.post_id] do
      {:noreply, stream_insert(socket, :suggestions, suggestion, at: 0)}
    else
      {:noreply, socket}
    end
  end

  def handle_info({:suggestion_resolved, suggestion}, socket) do
    {:noreply, stream_delete(socket, :suggestions, suggestion)}
  end

  # Splits the post around the suggested change so it can be shown in place.
  # Returns nil if the text can no longer be found exactly once.
  defp in_context(%{post: post, old_string: old_string}) do
    case Content.replace_once(post.markdown, old_string, "") do
      {:ok, _} ->
        [before, rest] = :binary.split(post.markdown, old_string)
        {String.slice(before, -@context_chars..-1//1), String.slice(rest, 0, @context_chars)}

      {:error, _} ->
        nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope} bare={@embed}>
      <header class={if(@embed, do: "mb-4", else: "mb-6")}>
        <h1 class={if(@embed, do: "text-lg font-semibold", else: "text-2xl font-semibold")}>
          Suggestions
        </h1>
        <p class="text-sm text-base-content/70">
          Edits proposed by Claude. Nothing changes until you accept it.
        </p>
      </header>

      <div id="suggestions" phx-update="stream" class="space-y-4">
        <p id="suggestions-empty" class="hidden only:block text-base-content/70">
          Nothing waiting for review.
        </p>

        <div
          :for={{dom_id, suggestion} <- @streams.suggestions}
          id={dom_id}
          phx-mounted={
            JS.transition(
              {"transition ease-out duration-500", "opacity-0 -translate-y-2",
               "opacity-100 translate-y-0"}
            )
          }
          class="card bg-base-100 shadow-sm"
        >
          <div class="card-body gap-3">
            <div class="flex items-start justify-between gap-4">
              <div>
                <%!-- narrowed to one post, its title would only repeat the editor --%>
                <.link
                  :if={is_nil(@post_id)}
                  navigate={~p"/office/posts/#{suggestion.post.id}"}
                  class="card-title link-hover"
                >
                  {suggestion.post.title}
                </.link>
                <p :if={suggestion.reason} class="text-sm text-base-content/70">
                  {suggestion.reason}
                </p>
              </div>
              <span class="badge badge-ghost badge-sm shrink-0">
                {Calendar.strftime(suggestion.inserted_at, "%Y-%m-%d %H:%M")}
              </span>
            </div>

            <%= case in_context(suggestion) do %>
              <% {before, rest} -> %>
                <pre class="whitespace-pre-wrap break-words rounded-box bg-base-200 p-3 font-mono text-sm leading-relaxed"><span class="text-base-content/60">…{before}</span><del class="bg-error/20 text-error line-through">{suggestion.old_string}</del><ins class="bg-success/20 text-success no-underline">{suggestion.new_string}</ins><span class="text-base-content/60">{rest}…</span></pre>
              <% nil -> %>
                <p class="alert alert-warning text-sm">
                  This text is no longer in the post exactly once. Accepting will mark it stale.
                </p>
            <% end %>

            <div class="card-actions justify-end">
              <button
                id={"reject-suggestion-#{suggestion.id}"}
                phx-click="reject"
                phx-value-id={suggestion.id}
                class="btn btn-ghost btn-sm"
              >
                Reject
              </button>
              <button
                id={"accept-suggestion-#{suggestion.id}"}
                phx-click="accept"
                phx-value-id={suggestion.id}
                class="btn btn-primary btn-sm"
              >
                <.icon name="hero-check" class="size-4" /> Accept
              </button>
            </div>
          </div>
        </div>
      </div>
    </Layouts.office>
    """
  end
end
