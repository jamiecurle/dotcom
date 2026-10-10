defmodule JamieWeb.PostmarkWebhookController do
  @moduledoc """
  Where Postmark posts what happened to our mail. Postmark doesn't sign its
  webhooks, so the endpoint is guarded by basic auth (the credentials go in
  the webhook url in Postmark's settings), and fails closed: without
  credentials configured it turns everything away.
  """
  use JamieWeb, :controller

  require Logger

  alias Jamie.MailingList.Webhooks

  plug :authenticate

  def create(conn, params) do
    case Webhooks.handle(params) do
      {:ok, _event} ->
        send_resp(conn, 200, "")

      # not something we know how to read: say so, and don't ask for a retry
      {:error, :unrecognised} ->
        send_resp(conn, 422, "")

      # anything else is our fault; a 500 makes Postmark try again later
      {:error, reason} ->
        Logger.error("Postmark webhook failed: #{inspect(reason)}")
        send_resp(conn, 500, "")
    end
  end

  defp authenticate(conn, _opts) do
    config = Application.get_env(:jamie, :postmark_webhook, [])

    case {config[:username], config[:password]} do
      {user, pass} when is_binary(user) and user != "" and is_binary(pass) and pass != "" ->
        Plug.BasicAuth.basic_auth(conn, username: user, password: pass)

      _not_configured ->
        conn |> send_resp(401, "") |> halt()
    end
  end
end
