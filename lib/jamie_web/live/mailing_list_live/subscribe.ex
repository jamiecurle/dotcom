defmodule JamieWeb.MailingListLive.Subscribe do
  @moduledoc """
  The sign-up form: an email, the worlds (or everything) and how often.
  Submitting it always ends in "check your inbox", whatever happened; see
  `Jamie.MailingList.subscribe/2` for why.
  """
  use JamieWeb, :live_view

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber
  alias Jamie.Service

  import JamieWeb.MailingListComponents

  @turnstile Service.get!(:turnstile)

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:body_id, "subscribe")
     |> assign(:page_title, "Subscribe")
     |> assign(:page_description, "Get new writing by email, a world at a time.")
     |> assign(:site_key, @turnstile.site_key())
     |> assign(:sent?, false)
     |> assign(:bot_check_failed?, false)
     |> assign_form(Subscriber.signup_changeset(%Subscriber{}, %{"frequency" => "weekly"}))}
  end

  @impl true
  def handle_event("validate", %{"subscriber" => params}, socket) do
    changeset =
      %Subscriber{}
      |> Subscriber.signup_changeset(params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  def handle_event("subscribe", %{"subscriber" => params} = all, socket) do
    with :ok <- @turnstile.verify(all["cf-turnstile-response"]),
         :ok <- MailingList.subscribe(params, &url_for/1) do
      {:noreply, assign(socket, sent?: true)}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, socket |> assign_form(changeset) |> reset_bot_check()}

      {:error, _bot_check} ->
        {:noreply, socket |> assign(:bot_check_failed?, true) |> reset_bot_check()}
    end
  end

  # each token is good for one try, so a failed submit needs a fresh one
  defp reset_bot_check(socket), do: push_event(socket, "turnstile:reset", %{})

  defp assign_form(socket, changeset), do: assign(socket, :form, to_form(changeset))

  defp url_for({:confirm, token}), do: url(~p"/subscribe/confirm/#{token}")
  defp url_for({:manage, id}), do: url(~p"/subscribe/#{id}")

  @impl true
  def render(assigns) do
    ~H"""
    <header class="masthead">
      <h1 class="page-title">Subscribe</h1>
      <p class="standfirst">
        New writing by email, from the worlds you choose, as often as suits you.
      </p>
    </header>

    <section class="page-content subscribe">
      <%= if @sent? do %>
        <div id="subscribe-sent" class="subscribe-sent">
          <h2>Check your inbox</h2>
          <p>
            If that address can be subscribed, an email is on its way with a link to confirm.
            Nothing is sent until you do.
          </p>
        </div>
      <% else %>
        <.form
          for={@form}
          id="subscribe-form"
          phx-change="validate"
          phx-submit="subscribe"
          class="subscribe-form"
        >
          <%!-- a floating label: see .field.floating in subscribe.css --%>
          <div class="field floating">
            <label for={@form[:email].id}>Your email</label>
            <input
              type="email"
              placeholder=" "
              id={@form[:email].id}
              name={@form[:email].name}
              value={@form[:email].value}
              autocomplete="email"
              required
              phx-debounce="blur"
            />
            <p :for={msg <- errors(@form[:email])} class="error">{msg}</p>
          </div>

          <.preferences form={@form} />

          <%!-- Turnstile draws itself in here and adds its token to the form --%>
          <div
            id="turnstile"
            phx-hook="Turnstile"
            phx-update="ignore"
            data-sitekey={@site_key}
          >
          </div>
          <p :if={@bot_check_failed?} id="bot-check-failed" class="error">
            That didn't pass the check for bots. Please try again.
          </p>

          <button type="submit" id="subscribe-submit" phx-disable-with="Subscribing…">
            Subscribe
          </button>

          <p class="small-print">
            Just your email address, kept only to send you these. Every email has a link to
            change what you get or leave. See the <.link navigate={~p"/privacy"}>privacy notice</.link>.
          </p>
        </.form>
      <% end %>
    </section>
    """
  end
end
