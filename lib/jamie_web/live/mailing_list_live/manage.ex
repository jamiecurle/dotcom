defmodule JamieWeb.MailingListLive.Manage do
  @moduledoc """
  A subscriber's own page, at `/subscribe/<their id>`: change the worlds or
  how often, or unsubscribe. The id in the url is the only key, so it lives
  behind the :secret_url pipeline (no referrer, no indexing) and is kept
  out of analytics and the request log.
  """
  use JamieWeb, :live_view

  import JamieWeb.MailingListComponents

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # an unknown, malformed or still-pending id is the same plain 404
    subscriber = MailingList.get_manageable(id) || raise JamieWeb.NotFoundError

    {:ok,
     socket
     |> assign(:body_id, "subscribe")
     |> assign(:page_title, "Your subscription")
     |> assign(:subscriber, subscriber)
     |> assign(:saved?, false)
     |> assign(:unsubscribed?, false)
     |> assign_form(Subscriber.preferences_changeset(subscriber, %{}))}
  end

  @impl true
  def handle_event("validate", %{"subscriber" => params}, socket) do
    changeset =
      socket.assigns.subscriber
      |> Subscriber.preferences_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, socket |> assign(:saved?, false) |> assign_form(changeset)}
  end

  def handle_event("save", %{"subscriber" => params}, socket) do
    case MailingList.update_preferences(socket.assigns.subscriber, params) do
      {:ok, subscriber} ->
        {:noreply,
         socket
         |> assign(subscriber: subscriber, saved?: true)
         |> assign_form(Subscriber.preferences_changeset(subscriber, %{}))}

      {:error, changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  def handle_event("unsubscribe", _params, socket) do
    {:ok, _} = MailingList.unsubscribe(socket.assigns.subscriber)
    {:noreply, assign(socket, :unsubscribed?, true)}
  end

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  @impl true
  def render(assigns) do
    ~H"""
    <header class="masthead">
      <h1 class="page-title">
        {if @unsubscribed?, do: "You're unsubscribed", else: "Your subscription"}
      </h1>
      <p :if={!@unsubscribed?} class="standfirst">{@subscriber.email}</p>
    </header>

    <section class="page-content subscribe">
      <%= if @unsubscribed? do %>
        <div id="subscribe-unsubscribed" class="subscribe-sent">
          <p>
            Done. Your address has been deleted, along with everything else about your
            subscription, so this link no longer works. Thank you for reading.
          </p>
          <p><.link navigate={~p"/subscribe"}>Subscribe again</.link> any time.</p>
        </div>
      <% else %>
        <p :if={@subscriber.status == :suspended} id="subscribe-suspended" class="notice">
          Emails to this address kept bouncing, so they're paused for now.
        </p>

        <.form
          for={@form}
          id="manage-form"
          phx-change="validate"
          phx-submit="save"
          class="subscribe-form"
        >
          <.preferences form={@form} />

          <div class="actions">
            <button type="submit" id="manage-save" phx-disable-with="Saving…">
              Save
            </button>
            <span :if={@saved?} id="manage-saved" class="saved" role="status">Saved</span>
          </div>
        </.form>

        <div id="unsubscribe" class="unsubscribe">
          <h2>Leave</h2>
          <p>
            Unsubscribing deletes your address and everything about this subscription.
          </p>
          <button
            type="button"
            id="unsubscribe-button"
            phx-click="unsubscribe"
            data-confirm="Unsubscribe and delete your address?"
          >
            Unsubscribe
          </button>
        </div>
      <% end %>
    </section>
    """
  end
end
