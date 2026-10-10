defmodule JamieWeb.MailingListLive.Subscribe do
  @moduledoc """
  Where people sign up for the mailing list. For now it only says what's
  coming; the form arrives with double opt-in.
  """
  use JamieWeb, :live_view

  alias Jamie.MailingList

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:body_id, "subscribe")
     |> assign(:page_title, "Subscribe")
     |> assign(:page_description, "Get new writing by email, a world at a time.")
     |> assign(:worlds, MailingList.worlds())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <header class="masthead">
      <h1 class="page-title">Subscribe</h1>
      <p class="standfirst">New writing by email, from the worlds you choose.</p>
    </header>

    <section class="page-content">
      <article>
        <ul id="worlds">
          <li :for={world <- @worlds} id={"world-#{world}"}>{world}</li>
        </ul>
      </article>
    </section>
    """
  end
end
