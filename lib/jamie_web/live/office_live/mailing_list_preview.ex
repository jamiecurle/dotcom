defmodule JamieWeb.OfficeLive.MailingListPreview do
  @moduledoc """
  The mailing list's emails, previewed: the HTML in a frame at inbox width,
  the plain text beside it, links to open either raw in a tab, and a button
  that sends a test digest to whoever's signed in, since the schedule sends
  nothing while the mailing list is switched off.
  """
  use JamieWeb, :live_view

  alias Jamie.MailingList.{Notifier, Previews}
  alias JamieWeb.MailingListUrls

  @impl true
  def mount(_params, _session, socket), do: {:ok, socket}

  @impl true
  def handle_params(params, _url, socket) do
    name = if params["email"] in Previews.emails(), do: params["email"], else: "digest"

    frequency =
      if params["frequency"] in Previews.frequencies(), do: params["frequency"], else: "weekly"

    {:noreply,
     socket
     |> assign(name: name, frequency: frequency)
     |> assign(:email, Previews.email(name, frequency, &MailingListUrls.url_for/1))}
  end

  @impl true
  def handle_event("send_test", _params, socket) do
    to = socket.assigns.current_scope.user.email
    posts = Previews.latest_posts()
    frequency = Previews.frequency(socket.assigns.frequency)

    socket =
      if posts == [] do
        put_flash(socket, :error, "Nothing's published, so there's no digest to send")
      else
        case Notifier.deliver_test_digest(to, posts, frequency, &MailingListUrls.url_for/1) do
          {:ok, _email} -> put_flash(socket, :info, "Test digest sent to #{to}")
          {:error, reason} -> put_flash(socket, :error, "Postmark said no: #{inspect(reason)}")
        end
      end

    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.office flash={@flash} current_scope={@current_scope}>
      <header class="mb-6 flex flex-wrap items-center gap-3">
        <.link navigate={~p"/office/mailing-list"} class="btn btn-ghost btn-sm">
          <.icon name="hero-arrow-left" class="size-4" /> Mailing list
        </.link>
        <h1 class="text-2xl font-semibold">Email previews</h1>
      </header>

      <div class="mb-4 flex flex-wrap items-center gap-3">
        <div role="tablist" id="preview-emails" class="tabs tabs-box">
          <.link
            :for={name <- Previews.emails()}
            id={"preview-#{name}"}
            role="tab"
            patch={~p"/office/mailing-list/preview?#{[email: name, frequency: @frequency]}"}
            class={["tab", name == @name && "tab-active"]}
          >
            {String.replace(name, "-", " ")}
          </.link>
        </div>

        <div :if={@name == "digest"} role="tablist" id="preview-frequencies" class="tabs tabs-box">
          <.link
            :for={frequency <- Previews.frequencies()}
            id={"preview-#{frequency}"}
            role="tab"
            patch={~p"/office/mailing-list/preview?#{[email: "digest", frequency: frequency]}"}
            class={["tab", frequency == @frequency && "tab-active"]}
          >
            {frequency}
          </.link>
        </div>

        <button
          :if={@name == "digest"}
          id="send-test-digest"
          phx-click="send_test"
          phx-disable-with="Sending…"
          class="btn btn-primary btn-sm ml-auto"
        >
          <.icon name="hero-paper-airplane" class="size-4" /> Send me a test digest
        </button>
      </div>

      <div class="card mb-4 bg-base-100 shadow-sm">
        <div class="card-body gap-1 py-4">
          <p class="text-sm text-base-content/60">Subject</p>
          <p id="preview-subject" class="font-semibold">{@email.subject}</p>
          <p class="text-sm text-base-content/60">
            Open raw: <a href={raw_path(@name, @frequency, "")} target="_blank" class="link">HTML</a>
            · <a href={raw_path(@name, @frequency, ".txt")} target="_blank" class="link">text</a>
          </p>
        </div>
      </div>

      <div class="grid gap-4 xl:grid-cols-[640px_1fr]">
        <%!-- the email as sent, at the width inboxes give it --%>
        <iframe
          id="preview-html"
          src={raw_path(@name, @frequency, "")}
          sandbox=""
          title="HTML email"
          class="h-[80vh] w-full rounded-box border border-base-300 bg-white"
        >
        </iframe>
        <pre
          id="preview-text"
          class="h-[80vh] overflow-auto whitespace-pre-wrap rounded-box bg-base-200 p-4 font-mono text-sm"
        >{@email.text_body}</pre>
      </div>
    </Layouts.office>
    """
  end

  defp raw_path(name, frequency, ext),
    do: ~p"/office/mailing-list/emails/#{name <> ext}?#{[frequency: frequency]}"
end
