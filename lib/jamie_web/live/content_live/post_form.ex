defmodule JamieWeb.ContentLive.PostForm do
  use JamieWeb, :live_view
  @moduledoc false

  alias Jamie.Bluesky
  alias Jamie.Content
  alias Jamie.Tags

  # The editor's modes, in the order the switch shows them. A mode name from
  # the client is looked up here rather than turned into an atom.
  @modes [
    {:preview, "Preview", "hero-eye"},
    {:editing, "Editing", "hero-chat-bubble-left-right"},
    {:writing, "Writing", "hero-pencil"}
  ]
  @mode_names Map.new(@modes, fn {mode, _label, _icon} -> {to_string(mode), mode} end)

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope} full_bleed>
      <div class="editor-split">
        <div class="editor-pane">
          <.form
            for={@form}
            id="editor-form"
            phx-change="validate"
            phx-debounce="1500"
            phx-submit="save"
            phx-hook="SaveShortcut"
          >
            <.input
              field={@form[:title]}
              label="Title"
              type="text-naked"
              placeholder="Post title"
              class="editor-title"
              phx-debounce="1500"
              required
            />

            <%!-- status as a segmented control: real radios named post[status],
                 styled as a daisyUI join, the chosen one coloured by status --%>
            <div
              id="post-status"
              class="flex flex-wrap items-center gap-3 border-b border-base-300 px-3 py-2"
            >
              <div class="join" role="radiogroup" aria-label="Status">
                <input
                  :for={status <- Content.Post.statuses()}
                  type="radio"
                  name={@form[:status].name}
                  id={"post-status-#{status}"}
                  value={status}
                  aria-label={String.capitalize(to_string(status))}
                  checked={to_string(@form[:status].value) == to_string(status)}
                  class={[
                    "join-item btn btn-sm",
                    to_string(@form[:status].value) == to_string(status) && status_class(status)
                  ]}
                />
              </div>
              <span class="ml-auto text-xs text-base-content/60">
                <%= if @post.published_on do %>
                  Published {Calendar.strftime(@post.published_on, "%-d %b %Y")}
                <% else %>
                  Not published yet
                <% end %>
              </span>
            </div>

            <.input
              type="text-naked"
              field={@form[:description]}
              label="Description"
              placeholder="Brief description"
              class="editor-standfirst"
              phx-debounce="1500"
            />

            <.input
              field={@form[:markdown]}
              type="textarea-naked"
              label="Content (Markdown)"
              class="editor-body min-h-96"
              placeholder="Write your post in markdown..."
              phx-hook="SignImageUrl"
              phx-debounce="1500"
            />

            <%!-- the chips below are the source of truth; this carries them
                 to save_post along with everything else --%>
            <input type="hidden" name="post[tag_list]" value={Enum.join(@tags, ",")} />
          </.form>

          <%!-- Tags and actions live below the form: the tag input has its own
               form, and forms can't nest, so Save submits #editor-form by id --%>
          <div id="editor-footer" class="mt-4 flex flex-col gap-3">
            <div
              id="post-tags"
              class="flex flex-wrap items-center gap-2 rounded-box border border-base-300 bg-base-200/60 px-3 py-2 transition-colors focus-within:border-primary"
            >
              <.icon name="hero-tag" class="size-4 shrink-0 opacity-50" />

              <span
                :for={tag <- @tags}
                id={"tag-#{tag}"}
                class="badge badge-soft badge-primary gap-1 pr-1 font-medium"
              >
                {tag}
                <button
                  type="button"
                  phx-click="remove-tag"
                  phx-value-tag={tag}
                  class="btn btn-ghost btn-circle btn-xs size-4 min-h-0"
                  aria-label={"Remove #{tag}"}
                >
                  <.icon name="hero-x-mark" class="size-3" />
                </button>
              </span>

              <form
                id="tag-form"
                phx-submit="add-tag"
                phx-change="suggest-tags"
                class="dropdown dropdown-top min-w-32 flex-1"
              >
                <input
                  id="tag-input"
                  phx-hook="TagInput"
                  name="tag"
                  value={@tag_query}
                  type="text"
                  autocomplete="off"
                  placeholder={if @tags == [], do: "Add tags…", else: "Add another"}
                  phx-debounce="150"
                  phx-keydown="tag-backspace"
                  phx-key="Backspace"
                  class="input input-ghost input-sm w-full border-0 px-1 shadow-none focus:outline-none"
                />
                <ul
                  :if={@tag_suggestions != []}
                  id="tag-suggestions"
                  class="dropdown-content menu menu-sm z-10 mb-2 w-56 rounded-box border border-base-300 bg-base-100 p-1 shadow-lg"
                >
                  <li class="menu-title">Existing tags</li>
                  <li :for={suggestion <- @tag_suggestions}>
                    <button type="button" phx-click="pick-tag" phx-value-tag={suggestion}>
                      <.icon name="hero-tag" class="size-3 opacity-50" />
                      {suggestion}
                    </button>
                  </li>
                </ul>
              </form>
            </div>

            <div class="flex items-center gap-2">
              <button
                type="submit"
                form="editor-form"
                class="btn btn-primary"
                phx-disable-with="Saving..."
              >
                Save Post
              </button>
              <%!-- what sits beside the editor: the live post (preview mode),
                   Claude's suggestions for this post (editing mode), or
                   nothing at all (writing mode) --%>
              <div
                :if={@live_action == :edit}
                id="editor-mode"
                class="join"
                role="group"
                aria-label="Editor mode"
              >
                <button
                  :for={{mode, label, icon} <- @modes}
                  type="button"
                  id={"editor-mode-#{mode}"}
                  phx-click="set-mode"
                  phx-value-mode={mode}
                  aria-pressed={to_string(@mode == mode)}
                  class={[
                    "join-item btn btn-sm",
                    if(@mode == mode, do: "btn-active", else: "btn-ghost")
                  ]}
                >
                  <.icon name={icon} class="size-4" /> {label}
                </button>
              </div>
              <span
                :if={@tags != @saved_tags}
                id="tags-unsaved"
                class="badge badge-warning badge-soft badge-sm ml-auto"
              >
                Unsaved tags
              </span>
            </div>

            <%!-- Bluesky: once a post is published (and saved as such) it can
                 be announced on Bluesky, with the words checked first since
                 a post there can't be edited, only deleted and redone --%>
            <.bluesky_panel
              :if={@live_action == :edit and @post.status == :published}
              post={@post}
              configured?={@bluesky_configured?}
              composing?={@bluesky_composing?}
              pending={@bluesky_pending}
              error={@bluesky_error}
              form={@bluesky_form}
              thread={@bluesky_thread}
            />
          </div>
        </div>

        <div :if={@live_action == :edit and @mode == :preview} class="preview-pane">
          <iframe
            id="post-preview"
            src={~p"/posts/#{@post.slug}?#{[preview: true]}"}
            title="Post preview"
          />
        </div>

        <%!-- the suggestions page narrowed to this post, without the office
             navbar; accepting one saves the post, and this editor hears that
             over PubSub like any other save --%>
        <div :if={@live_action == :edit and @mode == :editing} class="preview-pane">
          <iframe
            id="post-suggestions"
            src={~p"/office/suggestions?#{[post_id: @post.id, embed: true]}"}
            title="Suggestions for this post"
          />
        </div>
      </div>
    </Layouts.office>
    """
  end

  attr :post, Content.Post, required: true
  attr :configured?, :boolean, required: true
  attr :composing?, :boolean, required: true
  attr :pending, :atom, default: nil
  attr :error, :string, default: nil
  attr :form, Phoenix.HTML.Form, required: true
  attr :thread, :any, default: nil

  defp bluesky_panel(assigns) do
    text = assigns.form[:text].value || ""

    assigns =
      assign(assigns,
        count: String.length(text),
        max: Bluesky.max_graphemes(),
        host: URI.parse(JamieWeb.Endpoint.url()).host
      )

    ~H"""
    <section
      id="bluesky"
      class="rounded-box border border-base-300 bg-base-200/60 px-4 py-3 transition-colors"
    >
      <div class="flex flex-wrap items-center gap-3">
        <span class="flex items-center gap-2 text-sm font-semibold">
          <.icon name="hero-cloud" class="size-4 text-info" /> Bluesky
        </span>

        <%= cond do %>
          <% not @configured? -> %>
            <span id="bluesky-not-configured" class="text-xs text-base-content/60">
              Not set up: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD are needed.
            </span>
          <% @pending -> %>
            <span id="bluesky-pending" class="flex items-center gap-2 text-sm text-base-content/70">
              <span class="loading loading-dots loading-sm"></span>
              {if @pending == :remove, do: "Removing…", else: "Publishing…"}
            </span>
          <% @post.bluesky_uri -> %>
            <span id="bluesky-published" class="badge badge-soft badge-info gap-1">
              <.icon name="hero-check" class="size-3" />
              Posted {Calendar.strftime(@post.bluesky_posted_at, "%-d %b %Y, %H:%M")}
            </span>
            <span
              :if={is_nil(@post.standard_document_uri)}
              id="bluesky-document-missing"
              class="badge badge-soft badge-warning"
            >
              standard.site record pending
            </span>
            <a
              id="bluesky-link"
              href={Bluesky.web_url(@post.bluesky_uri)}
              target="_blank"
              rel="noopener"
              class="link link-hover text-sm"
            >
              View on Bluesky <.icon name="hero-arrow-top-right-on-square" class="size-3" />
            </a>
            <button
              id="bluesky-remove"
              type="button"
              phx-click="bluesky-remove"
              data-confirm="Delete this post from Bluesky? Its replies and likes go with it."
              class="btn btn-ghost btn-sm ml-auto text-error"
            >
              Remove from Bluesky
            </button>
          <% not @composing? -> %>
            <button
              id="bluesky-compose"
              type="button"
              phx-click="bluesky-compose"
              class="btn btn-info btn-sm ml-auto transition-transform hover:-translate-y-px"
            >
              <.icon name="hero-paper-airplane" class="size-4" /> Publish to Bluesky
            </button>
          <% true -> %>
        <% end %>
      </div>

      <div :if={@error} id="bluesky-error" role="alert" class="alert alert-error alert-soft mt-3">
        <.icon name="hero-exclamation-triangle" class="size-4" />
        <span>{@error}</span>
      </div>

      <%!-- the conversation, for moderating what the blog shows; Bluesky
           itself is untouched by anything here --%>
      <div :if={@post.bluesky_uri} id="bluesky-replies" class="mt-3">
        <%= case @thread do %>
          <% nil -> %>
          <% :loading -> %>
            <span class="loading loading-dots loading-sm"></span>
          <% :unavailable -> %>
            <p class="text-xs text-base-content/60">Couldn't fetch the replies from Bluesky.</p>
          <% thread -> %>
            <% replies = flatten(Bluesky.replies(thread, @post.bluesky_hidden_replies)) %>
            <p :if={replies == []} id="bluesky-no-replies" class="text-xs text-base-content/60">
              No replies yet.
            </p>
            <ul :if={replies != []} class="flex flex-col divide-y divide-base-300">
              <li
                :for={{reply, depth} <- replies}
                id={"bluesky-reply-#{reply_key(reply.uri)}"}
                class={["flex items-start gap-3 py-2", reply.hidden && "opacity-60"]}
                style={"padding-left: #{depth * 1.25}rem"}
              >
                <div class="min-w-0 flex-1">
                  <div class="flex flex-wrap items-baseline gap-x-2 text-xs">
                    <span class="font-semibold">{reply.name}</span>
                    <span class="text-base-content/60">@{reply.handle}</span>
                    <span
                      :if={reply.hidden}
                      class={[
                        "badge badge-xs badge-soft",
                        if(reply.hidden == :label, do: "badge-error", else: "badge-warning")
                      ]}
                    >
                      {hidden_label(reply.hidden)}
                    </span>
                  </div>
                  <p class="line-clamp-2 text-sm">{reply.text}</p>
                </div>
                <button
                  :if={reply.hidden in [nil, :blog]}
                  id={"bluesky-toggle-#{reply_key(reply.uri)}"}
                  type="button"
                  phx-click="bluesky-toggle-reply"
                  phx-value-uri={reply.uri}
                  class="btn btn-ghost btn-xs shrink-0"
                >
                  <.icon
                    name={if reply.hidden, do: "hero-eye", else: "hero-eye-slash"}
                    class="size-3"
                  />
                  {if reply.hidden, do: "Show on blog", else: "Hide on blog"}
                </button>
              </li>
            </ul>
        <% end %>
      </div>

      <.form
        :if={@composing? and @configured? and is_nil(@pending) and is_nil(@post.bluesky_uri)}
        for={@form}
        id="bluesky-form"
        phx-change="bluesky-change"
        phx-submit="bluesky-publish"
        class="mt-3 flex flex-col gap-3"
      >
        <.input
          field={@form[:text]}
          type="textarea"
          label="What the post says"
          rows="4"
          phx-debounce="100"
        />

        <%!-- the link card Bluesky will draw under the text --%>
        <div
          id="bluesky-card"
          class="flex overflow-hidden rounded-box border border-base-300 bg-base-100"
        >
          <img
            :if={@post.og_hash}
            src={"https://#{Application.get_env(:jamie, :images)[:host]}/opengraph/#{@post.og_hash}.png"}
            alt=""
            class="w-32 shrink-0 object-cover"
          />
          <div class="min-w-0 px-3 py-2">
            <div class="text-xs text-base-content/60">{@host}</div>
            <div class="truncate text-sm font-semibold">{@post.title}</div>
            <div class="line-clamp-2 text-xs text-base-content/70">{@post.description}</div>
          </div>
        </div>

        <div class="flex items-center gap-2">
          <span
            id="bluesky-count"
            class={[
              "text-xs tabular-nums",
              if(@count > @max, do: "font-semibold text-error", else: "text-base-content/60")
            ]}
          >
            {@count} / {@max}
          </span>
          <button
            type="button"
            id="bluesky-cancel"
            phx-click="bluesky-cancel"
            class="btn btn-ghost btn-sm ml-auto"
          >
            Cancel
          </button>
          <button
            type="submit"
            id="bluesky-publish"
            class="btn btn-info btn-sm"
            disabled={@count == 0 or @count > @max}
            phx-disable-with="Queuing…"
          >
            Publish
          </button>
        </div>
      </.form>
    </section>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # writing mode is the default: just the editor until another is picked
    {:ok,
     assign(socket,
       mode: :writing,
       modes: @modes,
       bluesky_configured?: Bluesky.configured?(),
       bluesky_composing?: false,
       bluesky_pending: nil,
       bluesky_error: nil,
       bluesky_thread: nil,
       bluesky_form: to_form(%{"text" => ""}, as: :bluesky)
     )}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("set-mode", %{"mode" => mode}, socket) do
    {:noreply, assign(socket, :mode, Map.get(@mode_names, mode, socket.assigns.mode))}
  end

  def handle_event("sign-image-url", %{"name" => name}, socket) do
    host = Application.get_env(:jamie, :images)[:host]
    bucket = Application.get_env(:ex_aws, :s3)[:bucket]
    # The prefix must be part of the S3 key, not just the public URL —
    # otherwise we sign a PUT for the bucket root and link to /posts/.
    key = "posts/" <> Ecto.UUID.generate() <> Path.extname(name)

    {:ok, url} =
      :s3
      |> ExAws.Config.new([])
      |> ExAws.S3.presigned_url(:put, bucket, key)

    {:noreply,
     push_event(socket, "page-loading-stop", %{
       name: name,
       url: url,
       public_url: "https://#{host}/#{key}"
     })}
  end

  @impl true
  def handle_event("validate", %{"post" => post_params}, socket) do
    changeset =
      socket.assigns.post
      |> Content.change_post(post_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  @impl true
  def handle_event("save", %{"post" => post_params}, socket) do
    save_post(socket, socket.assigns.live_action, post_params)
  end

  # BLUESKY

  def handle_event("bluesky-compose", _params, socket) do
    post = socket.assigns.post
    text = Bluesky.post_text(post.title, post.description)

    {:noreply,
     assign(socket,
       bluesky_composing?: true,
       bluesky_error: nil,
       bluesky_form: to_form(%{"text" => text}, as: :bluesky)
     )}
  end

  def handle_event("bluesky-cancel", _params, socket) do
    {:noreply, assign(socket, bluesky_composing?: false)}
  end

  def handle_event("bluesky-change", %{"bluesky" => params}, socket) do
    {:noreply, assign(socket, bluesky_form: to_form(params, as: :bluesky))}
  end

  def handle_event("bluesky-publish", %{"bluesky" => %{"text" => text}}, socket) do
    case Content.publish_to_bluesky(socket.assigns.post, text) do
      {:ok, _job} ->
        {:noreply,
         assign(socket, bluesky_pending: :publish, bluesky_composing?: false, bluesky_error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, bluesky_error: bluesky_message(reason))}
    end
  end

  def handle_event("bluesky-remove", _params, socket) do
    case Content.remove_from_bluesky(socket.assigns.post) do
      {:ok, _job} ->
        {:noreply, assign(socket, bluesky_pending: :remove, bluesky_error: nil)}

      {:error, reason} ->
        {:noreply, assign(socket, bluesky_error: bluesky_message(reason))}
    end
  end

  def handle_event("bluesky-toggle-reply", %{"uri" => uri}, socket) do
    # the broadcast that follows brings the updated post back to this view
    {:ok, _post} = Content.toggle_bluesky_reply(socket.assigns.post, uri)
    {:noreply, socket}
  end

  # TAGS
  # The chips are held in @tags until Save Post; @saved_tags is what's in the
  # database, so the footer can say when they differ.

  # Enter in the tag input. Commas split it, so "elixir, trees" adds both.
  def handle_event("add-tag", %{"tag" => text}, socket) do
    {:noreply, socket |> add_tags(String.split(text, ",")) |> clear_tag_input()}
  end

  def handle_event("pick-tag", %{"tag" => tag}, socket) do
    {:noreply, socket |> add_tags([tag]) |> clear_tag_input()}
  end

  # Typing a comma commits everything before it, like most tag inputs; the
  # word after the last comma is still being typed, so it stays in the box
  # and drives the suggestions.
  def handle_event("suggest-tags", %{"tag" => text}, socket) do
    {done, [typing]} = text |> String.split(",") |> Enum.split(-1)

    socket = add_tags(socket, done)

    socket =
      if done == [], do: socket, else: push_event(socket, "set-tag-input", %{value: typing})

    {:noreply,
     socket
     |> assign(:tag_query, typing)
     |> assign(:tag_suggestions, Tags.suggest_tags(typing, socket.assigns.tags))}
  end

  def handle_event("remove-tag", %{"tag" => tag}, socket) do
    {:noreply, update(socket, :tags, &List.delete(&1, tag))}
  end

  # Backspace in an empty input takes the last chip off.
  def handle_event("tag-backspace", %{"value" => ""}, socket) do
    {:noreply, update(socket, :tags, &Enum.drop(&1, -1))}
  end

  def handle_event("tag-backspace", _params, socket), do: {:noreply, socket}

  defp add_tags(socket, titles) do
    update(socket, :tags, &normalise_tags(&1 ++ titles))
  end

  defp clear_tag_input(socket) do
    socket
    |> assign(tag_query: "", tag_suggestions: [])
    |> push_event("set-tag-input", %{value: ""})
  end

  # trimmed, lowercased, no blanks or repeats, in the order they were added
  defp normalise_tags(titles) do
    titles
    |> Enum.map(&(&1 |> String.trim() |> String.downcase()))
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp assign_tags(socket, post) do
    tags = Tags.post_tag_titles(post)

    assign(socket,
      tags: tags,
      saved_tags: tags,
      tag_query: "",
      tag_suggestions: []
    )
  end

  # Our own saves broadcast too; by the time the message arrives we've already
  # assigned the saved post, so matching updated_at means there's nothing new.
  @impl true
  def handle_info({:post_updated, %{updated_at: updated_at}}, socket)
      when updated_at == socket.assigns.post.updated_at do
    {:noreply, socket}
  end

  # The publish worker's progress. Only the bluesky fields change, so the
  # post can be swapped in without touching the draft or its updated_at.
  def handle_info({:post_bluesky, post}, socket) do
    uri_changed? = post.bluesky_uri != socket.assigns.post.bluesky_uri

    pending =
      case socket.assigns.bluesky_pending do
        :publish when is_binary(post.standard_document_uri) -> nil
        :remove when is_nil(post.bluesky_uri) -> nil
        pending -> pending
      end

    socket = assign(socket, post: post, bluesky_pending: pending)

    # published or removed from here: follow the new thread, or none
    socket = if uri_changed?, do: fetch_bluesky_thread(socket), else: socket

    {:noreply, socket}
  end

  def handle_info({:bluesky_error, _post_id, message}, socket) do
    {:noreply, assign(socket, bluesky_pending: nil, bluesky_error: message)}
  end

  def handle_info({:post_updated, post}, socket) do
    %{post: base, form: form} = socket.assigns
    draft = form.params["markdown"] || base.markdown

    # Carry the outside change into whatever is in the editor, so a clean
    # editor shows the new text and a dirty one keeps its unsaved work too.
    case Content.rebase_draft(base.markdown, post.markdown, draft) do
      {:ok, merged} ->
        params = Map.put(form.params, "markdown", merged)

        {:noreply,
         socket
         # the new post becomes the base, so the next save doesn't conflict
         |> assign(:post, post)
         |> assign(:form, to_form(Content.change_post(post, params)))
         # LiveView won't patch a focused textarea, so the hook sets it
         |> push_event("set-markdown", %{markdown: merged})
         |> put_flash(:info, "Merged a change made elsewhere into the editor.")}

      {:error, :conflict} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           "This post was changed elsewhere in the same place you're editing. Copy anything you need, then reload to see the latest version."
         )}
    end
  end

  # the reply tree as rows, each with how deep it sits
  defp flatten(replies, depth \\ 0) do
    Enum.flat_map(replies, fn reply -> [{reply, depth} | flatten(reply.replies, depth + 1)] end)
  end

  defp reply_key(uri) do
    {:ok, %{repo: repo, rkey: rkey}} = Bluesky.parse_uri(uri)
    String.replace(repo, ":", "-") <> "-" <> rkey
  end

  defp hidden_label(:bluesky), do: "Hidden on Bluesky"
  defp hidden_label(:label), do: "Labelled by Bluesky"
  defp hidden_label(:blog), do: "Hidden on blog"

  defp bluesky_message(:not_configured), do: "Bluesky isn't set up on this server."
  defp bluesky_message(:not_published), do: "Save the post as published first."
  defp bluesky_message(:already_published), do: "This post is already on Bluesky."
  defp bluesky_message(:not_on_bluesky), do: "This post isn't on Bluesky."
  defp bluesky_message(:blank), do: "The post needs some words."
  defp bluesky_message(:too_long), do: "Bluesky posts are 300 characters at most."
  defp bluesky_message(_), do: "Couldn't queue that for Bluesky."

  # the colour the chosen status button takes
  defp status_class(:published), do: "btn-success"
  defp status_class(:hidden), do: "btn-ghost btn-active"
  defp status_class(_draft), do: "btn-neutral"

  defp save_post(socket, :new, post_params) do
    case Content.create_post(post_params) do
      {:ok, post} ->
        save_tags(post, post_params)

        {:noreply,
         socket
         |> put_flash(:info, "Post Saved")
         |> push_navigate(to: ~p"/office/posts/#{post.id}")}

      %Ecto.Changeset{} = changeset ->
        {:noreply,
         socket
         |> put_flash(:error, "could not save post")
         |> assign(form: to_form(changeset))}
    end
  end

  defp save_post(socket, :edit, post_params) do
    post = socket.assigns.post

    case Content.update_post(post, post_params, post.updated_at) do
      {:ok, updated} ->
        save_tags(updated, post_params)

        {:noreply,
         socket
         |> assign(:post, updated)
         |> assign_tags(updated)
         |> assign(:form, to_form(Content.change_post(updated)))
         |> put_flash(:info, "Post updated successfully.")}

      {:error, :conflict} ->
        {:noreply,
         socket
         |> put_flash(
           :error,
           "This post was changed in another tab. Reload to see the latest version before saving again."
         )}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end

  # Tags only change when the form actually sent the field, so a save that
  # leaves it out (or a test) doesn't wipe them.
  defp save_tags(post, %{"tag_list" => tag_list}) when is_binary(tag_list) do
    {:ok, _} = Tags.set_post_tags(post, String.split(tag_list, ","))
  end

  defp save_tags(_post, _params), do: :ok

  defp apply_action(socket, :new, _params) do
    post = %Content.Post{}
    changeset = Content.change_post(post)

    socket
    |> assign(:page_title, "new post")
    |> assign(:post, post)
    |> assign(:form, to_form(changeset))
    |> assign_tags(post)
  end

  defp apply_action(socket, :edit, params) do
    post = Content.get_post!(params["id"])

    # Hear about saves made elsewhere — another tab, or an accepted MCP
    # suggestion — so this editor doesn't sit on stale content.
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Jamie.PubSub, "post:#{post.id}")
    end

    changeset =
      Content.change_post(post)

    socket
    |> assign(:page_title, "Editing #{post.title}")
    |> assign(:post, post)
    |> assign(:form, to_form(changeset))
    |> assign_tags(post)
    |> fetch_bluesky_thread()
  end

  # The replies to moderate, fetched once the editor is live. Toggling one
  # only changes which uris the post hides, so the thread isn't refetched.
  defp fetch_bluesky_thread(%{assigns: %{post: %{bluesky_uri: uri}}} = socket)
       when is_binary(uri) do
    if connected?(socket) do
      socket
      |> assign(:bluesky_thread, :loading)
      |> start_async(:bluesky_thread, fn -> Bluesky.get_thread(uri) end)
    else
      socket
    end
  end

  defp fetch_bluesky_thread(socket), do: assign(socket, :bluesky_thread, nil)

  @impl true
  def handle_async(:bluesky_thread, {:ok, {:ok, thread}}, socket) do
    {:noreply, assign(socket, :bluesky_thread, thread)}
  end

  def handle_async(:bluesky_thread, _failed, socket) do
    {:noreply, assign(socket, :bluesky_thread, :unavailable)}
  end
end
