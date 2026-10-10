defmodule JamieWeb.OneClickUnsubscribeController do
  @moduledoc """
  RFC 8058 one-click unsubscribe. Every digest's `List-Unsubscribe` header
  points here, and Gmail, Yahoo and others POST to it when someone presses
  their own "unsubscribe" button, without a session or CSRF token. The
  subscriber's id in the url is the only key, as on the manage page.

  It always answers 200, whether or not there was anyone to unsubscribe,
  so it can't be used to test ids. Unsubscribing works whether or not the
  mailing list is switched on.
  """
  use JamieWeb, :controller

  alias Jamie.MailingList

  def create(conn, %{"id" => id}) do
    with %{} = subscriber <- MailingList.get_subscriber(id) do
      {:ok, _} = MailingList.unsubscribe(subscriber)
    end

    send_resp(conn, 200, "")
  end

  # a person following the link in a browser gets the manage page instead
  def show(conn, %{"id" => id}), do: redirect(conn, to: ~p"/subscribe/#{id}")
end
