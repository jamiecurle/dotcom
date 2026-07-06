defmodule JamieWeb.UserLive.Login do
  use JamieWeb, :live_view

  alias Jamie.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_scope={@current_scope}>
      <div class="card w-full max-w-md bg-base-100 shadow-xl">
        <div class="card-body gap-4">
          <h1 class="text-xl text-base-content/80">login</h1>

          <p :if={@current_scope} class="text-sm text-base-content/60">
            You need to reauthenticate to perform sensitive actions on your account.
          </p>

          <div :if={local_mail_adapter?()} class="alert alert-info alert-soft">
            <.icon name="hero-information-circle" class="size-5 shrink-0" />
            <span>
              Local mail adapter — sent emails appear in <.link href="/dev/mailbox" class="link">the mailbox</.link>.
            </span>
          </div>

          <.form
            :let={f}
            for={@form}
            id="login_form_magic"
            action={~p"/front-door/log-in"}
            phx-submit="submit_magic"
          >
            <fieldset class="fieldset">
              <label class="fieldset-label" for={f[:email].id}>Email</label>
              <label class="input w-full">
                <.icon name="hero-envelope" class="size-4 opacity-60" />
                <input
                  type="email"
                  name={f[:email].name}
                  id={f[:email].id}
                  value={Phoenix.HTML.Form.normalize_value("email", f[:email].value)}
                  placeholder="Email"
                  autocomplete="username"
                  spellcheck="false"
                  readonly={!!@current_scope}
                  required
                  phx-mounted={JS.focus()}
                  class="grow"
                />
              </label>

              <button
                type="submit"
                class="btn btn-accent mt-4 self-start"
                phx-disable-with="Sending..."
              >
                <.icon name="hero-heart-solid" class="size-4" /> Login
              </button>
            </fieldset>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    email =
      Phoenix.Flash.get(socket.assigns.flash, :email) ||
        get_in(socket.assigns, [:current_scope, Access.key(:user), Access.key(:email)])

    form = to_form(%{"email" => email}, as: "user")

    {:ok, assign(socket, form: form)}
  end

  @impl true
  def handle_event("submit_magic", %{"user" => %{"email" => email}}, socket) do
    if user = Accounts.get_user_by_email(email) do
      Accounts.deliver_login_instructions(
        user,
        &url(~p"/front-door/log-in/#{&1}")
      )
    end

    info =
      "If your email is in our system, you will receive instructions for logging in shortly."

    {:noreply,
     socket
     |> put_flash(:info, info)
     |> push_navigate(to: ~p"/front-door/log-in")}
  end

  defp local_mail_adapter? do
    Application.get_env(:jamie, Jamie.Mailer)[:adapter] == Swoosh.Adapters.Local
  end
end
