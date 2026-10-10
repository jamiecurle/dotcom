defmodule JamieWeb.MailingListLive.Confirm do
  @moduledoc """
  Where the confirmation email's link lands. Opening the link doesn't
  confirm anything; pressing the button does. Mail scanners and link
  previews fetch every link in an email, and they'd otherwise confirm
  subscriptions nobody asked for.
  """
  use JamieWeb, :live_view

  alias Jamie.MailingList

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    {:ok,
     socket
     |> assign(:body_id, "subscribe")
     |> assign(:page_title, "Confirm your subscription")
     |> assign(:subscriber, MailingList.get_pending_by_token(token))
     |> assign(:confirmed?, false)}
  end

  @impl true
  def handle_event("confirm", _params, %{assigns: %{subscriber: subscriber}} = socket)
      when not is_nil(subscriber) do
    {:ok, subscriber} = MailingList.confirm(subscriber)
    {:noreply, assign(socket, subscriber: subscriber, confirmed?: true)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="masthead">
      <h1 class="page-title">
        {if @confirmed?, do: "You're subscribed", else: "Confirm your subscription"}
      </h1>
    </header>

    <section class="page-content subscribe">
      <%= cond do %>
        <% @confirmed? -> %>
          <div id="subscribe-confirmed" class="subscribe-sent">
            <p>
              Thank you. The first email comes {when_first(@subscriber.frequency)}.
              Every email has a link to change what you get or unsubscribe.
            </p>
          </div>
        <% @subscriber -> %>
          <div id="subscribe-confirm" class="subscribe-sent">
            <p>
              Subscribe <strong>{@subscriber.email}</strong>
              to {worlds(@subscriber)}, {@subscriber.frequency}?
            </p>
            <button type="button" id="confirm-subscription" phx-click="confirm">
              Confirm
            </button>
          </div>
        <% true -> %>
          <div id="subscribe-expired" class="subscribe-sent">
            <p>
              This link has expired or already been used.
              You can <.link navigate={~p"/subscribe"}>sign up again</.link>.
            </p>
          </div>
      <% end %>
    </section>
    """
  end

  defp worlds(%{everything: true}), do: "everything"
  defp worlds(%{worlds: worlds}), do: Enum.join(worlds, ", ")

  defp when_first(:daily), do: "at the next 8am"
  defp when_first(:weekly), do: "on Friday"
  defp when_first(:monthly), do: "on the 28th"
end
