defmodule JamieWeb.ContentLive.PostForm do
  use JamieWeb, :live_view
  @moduledoc false

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

  @impl true
  def mount(_params, _session, socket) do
    # writing mode is the default: just the editor until another is picked
    {:ok, assign(socket, mode: :writing, modes: @modes)}
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
  end
end
