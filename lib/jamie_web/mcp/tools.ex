defmodule JamieWeb.Mcp.Tools do
  @moduledoc """
  The tools exposed to Claude over MCP.

  Everything here is read-only except `suggest_edit`, and even that only
  files a suggestion for review at `/office/suggestions` — no tool can change
  a post, its status, or anything else directly.
  """

  alias Jamie.Content
  alias Jamie.Content.{Post, PostSuggestion}

  @statuses Enum.map(Post.statuses(), &Atom.to_string/1)

  @tools [
    %{
      name: "list_posts",
      description:
        "List blog posts on jamiecurle.com (all statuses, newest first) with their id, title, slug, status and dates.",
      inputSchema: %{
        type: "object",
        properties: %{
          status: %{type: "string", enum: @statuses, description: "Only posts with this status."}
        }
      },
      annotations: %{readOnlyHint: true}
    },
    %{
      name: "get_post",
      description:
        "Fetch one post's full markdown and metadata, by id or slug. Use the markdown exactly as returned when choosing old_string for suggest_edit.",
      inputSchema: %{
        type: "object",
        properties: %{
          id: %{type: "integer"},
          slug: %{type: "string"}
        }
      },
      annotations: %{readOnlyHint: true}
    },
    %{
      name: "search_posts",
      description: "Case-insensitive text search across post titles, descriptions and markdown.",
      inputSchema: %{
        type: "object",
        properties: %{query: %{type: "string", minLength: 2}},
        required: ["query"]
      },
      annotations: %{readOnlyHint: true}
    },
    %{
      name: "suggest_edit",
      description: """
      Propose a find-and-replace edit to a post's markdown. This does NOT change the post: \
      it files a suggestion that Jamie reviews and accepts or rejects by hand. \
      old_string must match the current markdown exactly (including whitespace) and appear \
      exactly once — include enough surrounding text to make it unique. \
      Keep each suggestion small and focused, and explain why in reason.\
      """,
      inputSchema: %{
        type: "object",
        properties: %{
          post_id: %{type: "integer"},
          old_string: %{type: "string", description: "Exact text to replace; must occur once."},
          new_string: %{type: "string", description: "Replacement text; empty to delete."},
          reason: %{type: "string", description: "Why this change, e.g. the factual error."}
        },
        required: ["post_id", "old_string", "new_string", "reason"]
      },
      annotations: %{readOnlyHint: false, destructiveHint: false}
    },
    %{
      name: "list_suggestions",
      description:
        "List edit suggestions already filed, so you don't duplicate one. Defaults to pending ones.",
      inputSchema: %{
        type: "object",
        properties: %{
          post_id: %{type: "integer"},
          status: %{type: "string", enum: ["pending", "accepted", "rejected", "stale"]}
        }
      },
      annotations: %{readOnlyHint: true}
    }
  ]

  def list, do: @tools

  @doc """
  Runs a tool. Returns `{:ok, data}` to send back as the result, or
  `{:error, message}` for a tool-level error Claude can read and correct.
  """
  def call(_scope, "list_posts", args) do
    posts =
      case args do
        %{"status" => status} when status in @statuses ->
          Enum.filter(Content.all_posts(), &(Atom.to_string(&1.status) == status))

        _ ->
          Content.all_posts()
      end

    {:ok, %{posts: Enum.map(posts, &post_summary/1)}}
  end

  def call(scope, "get_post", %{"id" => id}) when is_integer(id) do
    case Content.get_post(id) do
      nil -> {:error, "No post with id #{id}."}
      post -> {:ok, post_detail(scope, post)}
    end
  end

  def call(scope, "get_post", %{"slug" => slug}) when is_binary(slug) do
    case Content.get_post_by_slug(slug) do
      nil -> {:error, "No post with slug #{inspect(slug)}."}
      post -> {:ok, post_detail(scope, post)}
    end
  end

  def call(_scope, "get_post", _args), do: {:error, "Pass an integer id or a slug."}

  def call(scope, "search_posts", %{"query" => query})
      when is_binary(query) and byte_size(query) >= 2 do
    {:ok, %{posts: scope |> Content.search_posts(query) |> Enum.map(&post_summary/1)}}
  end

  def call(_scope, "search_posts", _args), do: {:error, "query must be at least 2 characters."}

  def call(scope, "suggest_edit", %{"post_id" => post_id} = args) when is_integer(post_id) do
    attrs = Map.take(args, ["old_string", "new_string", "reason"])

    case Content.get_post(post_id) && Content.suggest_post_edit(scope, post_id, attrs) do
      nil ->
        {:error, "No post with id #{post_id}."}

      {:ok, suggestion} ->
        {:ok,
         %{
           suggestion: suggestion_summary(suggestion),
           note: "Filed for review. The post is unchanged until Jamie accepts it."
         }}

      {:error, :not_found} ->
        {:error,
         "old_string was not found in the post. Re-read it with get_post and copy exactly."}

      {:error, :ambiguous} ->
        {:error, "old_string appears more than once. Include more surrounding text."}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset_message(changeset)}
    end
  end

  def call(_scope, "suggest_edit", _args), do: {:error, "post_id must be an integer."}

  def call(scope, "list_suggestions", args) do
    status =
      case args["status"] do
        s when s in ["pending", "accepted", "rejected", "stale"] -> String.to_existing_atom(s)
        _ -> :pending
      end

    filters =
      case args["post_id"] do
        id when is_integer(id) -> [status: status, post_id: id]
        _ -> [status: status]
      end

    {:ok,
     %{suggestions: scope |> Content.list_suggestions(filters) |> Enum.map(&suggestion_summary/1)}}
  end

  def call(_scope, name, _args), do: {:error, "Unknown tool #{inspect(name)}."}

  defp post_summary(%Post{} = post) do
    %{
      id: post.id,
      title: post.title,
      slug: post.slug,
      status: post.status,
      description: post.description,
      published_on: post.published_on,
      updated_at: post.updated_at
    }
  end

  defp post_detail(scope, %Post{} = post) do
    pending = Content.list_suggestions(scope, status: :pending, post_id: post.id)

    post
    |> post_summary()
    |> Map.merge(%{
      edited_on: post.edited_on,
      url: if(post.status == :published, do: "https://jamiecurle.com/posts/#{post.slug}"),
      pending_suggestions: length(pending),
      markdown: post.markdown
    })
  end

  defp suggestion_summary(%PostSuggestion{} = s) do
    %{
      id: s.id,
      post_id: s.post_id,
      status: s.status,
      old_string: s.old_string,
      new_string: s.new_string,
      reason: s.reason,
      inserted_at: s.inserted_at
    }
  end

  defp changeset_message(changeset) do
    changeset
    |> Ecto.Changeset.traverse_errors(fn {msg, _opts} -> msg end)
    |> Enum.map_join("; ", fn {field, msgs} -> "#{field} #{Enum.join(msgs, ", ")}" end)
  end
end
