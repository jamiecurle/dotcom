defmodule JamieWeb.OfficeLive.McpTokens do
  @moduledoc """
  Create and revoke the bearer tokens Claude Desktop uses to reach `/mcp`.

  A freshly created token is held in `@new_token` for this LiveView process
  only, so it is shown once and is gone on the next page load.
  """
  use JamieWeb, :live_view

  alias Jamie.Accounts
  alias Jamie.Accounts.UserToken

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket |> assign(:new_token, nil) |> load_tokens()}
  end

  @impl true
  def handle_event("create", _params, socket) do
    {encoded_token, _user_token} = Accounts.create_mcp_token(socket.assigns.current_scope)

    {:noreply, socket |> assign(:new_token, encoded_token) |> load_tokens()}
  end

  def handle_event("revoke", %{"id" => id}, socket) do
    :ok = Accounts.delete_mcp_token(socket.assigns.current_scope, String.to_integer(id))

    {:noreply,
     socket
     |> put_flash(:info, "Token revoked.")
     |> load_tokens()}
  end

  defp load_tokens(socket) do
    assign(socket, :tokens, Accounts.list_mcp_tokens(socket.assigns.current_scope))
  end

  defp expires_on(%UserToken{inserted_at: inserted_at}) do
    inserted_at
    |> DateTime.add(UserToken.mcp_validity_in_days(), :day)
    |> DateTime.to_date()
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6 flex items-center justify-between">
        <div>
          <h1 class="text-2xl font-semibold">MCP tokens</h1>
          <p class="text-sm text-base-content/70">
            Bearer tokens for Claude Desktop. They only work over Tailscale and can only file suggestions.
          </p>
        </div>
        <button id="create-mcp-token" phx-click="create" class="btn btn-primary btn-sm">
          <.icon name="hero-plus" class="size-4" /> New token
        </button>
      </header>

      <div :if={@new_token} id="new-mcp-token" class="alert alert-warning mb-6 flex-col items-start">
        <p class="font-semibold">Copy this token now — it won't be shown again.</p>
        <code class="select-all break-all font-mono text-sm">{@new_token}</code>
      </div>

      <ul id="mcp-tokens" class="menu w-full rounded-box bg-base-100 shadow-sm">
        <li :for={token <- @tokens} id={"mcp-token-#{token.id}"}>
          <div class="flex justify-between">
            <span>
              Token #{token.id} · created {Calendar.strftime(token.inserted_at, "%Y-%m-%d")} · expires {expires_on(
                token
              )}
            </span>
            <button
              id={"revoke-mcp-token-#{token.id}"}
              phx-click="revoke"
              phx-value-id={token.id}
              data-confirm="Revoke this token?"
              class="btn btn-ghost btn-xs text-error"
            >
              Revoke
            </button>
          </div>
        </li>
        <li :if={@tokens == []} class="menu-disabled"><span>No tokens.</span></li>
      </ul>
    </Layouts.office>
    """
  end
end
