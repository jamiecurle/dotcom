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

  @turnstile Service.get!(:turnstile)

  # what the form says about each world
  @blurbs %{
    "treeworld" => "Woodland, trees and the land",
    "techworld" => "Software, the web and tools",
    "makerworld" => "The workshop and making things",
    "privacyworld" => "Privacy, data and the law",
    "foodworld" => "Cooking and eating",
    "miscworld" => "Everything else"
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:body_id, "subscribe")
     |> assign(:page_title, "Subscribe")
     |> assign(:page_description, "Get new writing by email, a world at a time.")
     |> assign(:worlds, Enum.map(MailingList.worlds(), &{&1, @blurbs[&1]}))
     |> assign(:frequencies, Subscriber.frequencies())
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

  # The manage page arrives in the next step, so its url is built by hand
  # rather than with ~p, which would warn about a route that isn't there.
  defp url_for({:confirm, token}), do: url(~p"/subscribe/confirm/#{token}")
  defp url_for({:manage, id}), do: JamieWeb.Endpoint.url() <> "/subscribe/" <> id

  defp checked?(form, world), do: world in (form[:worlds].value || [])

  defp everything?(form), do: form[:everything].value in [true, "true"]

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

          <fieldset id="subscribe-worlds">
            <legend>Worlds</legend>
            <ol class="worlds">
              <li>
                <input type="hidden" name={@form[:everything].name} value="false" />
                <label class="world everything" for="subscriber-everything">
                  <input
                    type="checkbox"
                    id="subscriber-everything"
                    name={@form[:everything].name}
                    value="true"
                    checked={everything?(@form)}
                  />
                  <span class="name">Everything</span>
                  <span class="blurb">All of it, and any world to come</span>
                </label>
              </li>
              <li :for={{world, blurb} <- @worlds}>
                <label class="world" for={"subscriber-world-#{world}"}>
                  <input
                    type="checkbox"
                    id={"subscriber-world-#{world}"}
                    name={@form[:worlds].name <> "[]"}
                    value={world}
                    checked={checked?(@form, world)}
                    disabled={everything?(@form)}
                  />
                  <span class="name">{world}</span>
                  <span class="blurb">{blurb}</span>
                </label>
              </li>
            </ol>
            <p :for={msg <- errors(@form[:worlds])} class="error">{msg}</p>
          </fieldset>

          <fieldset id="subscribe-frequency">
            <legend>How often</legend>
            <div class="frequencies">
              <label :for={frequency <- @frequencies} for={"subscriber-frequency-#{frequency}"}>
                <input
                  type="radio"
                  id={"subscriber-frequency-#{frequency}"}
                  name={@form[:frequency].name}
                  value={frequency}
                  checked={to_string(@form[:frequency].value) == to_string(frequency)}
                />
                <span>{frequency_label(frequency)}</span>
              </label>
            </div>
          </fieldset>

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

  defp frequency_label(:daily), do: "Daily, 8am"
  defp frequency_label(:weekly), do: "Weekly, Fridays"
  defp frequency_label(:monthly), do: "Monthly, the 28th"

  # once the field has been touched, as <.input> does, or after a submit
  # (an empty set of checkboxes sends nothing, so never counts as touched)
  defp errors(field) do
    if Phoenix.Component.used_input?(field) or field.form.source.action == :insert,
      do: Enum.map(field.errors, &JamieWeb.CoreComponents.translate_error/1),
      else: []
  end
end
