defmodule JamieWeb.MailingListEmailController do
  @moduledoc """
  The mailing list's emails served raw, to open straight in a browser:
  `/office/mailing-list/emails/digest` for the HTML exactly as an inbox
  gets it, `digest.txt` for the plain-text half. `?frequency=daily` picks
  the digest's wording. The office preview page frames these.
  """
  use JamieWeb, :controller

  alias Jamie.MailingList.Previews

  def show(conn, %{"email" => email} = params) do
    {name, format} = split_format(email)

    case Previews.email(
           name,
           params["frequency"] || "weekly",
           &JamieWeb.MailingListUrls.url_for/1
         ) do
      nil ->
        conn |> put_status(:not_found) |> text("No such email")

      %Swoosh.Email{} = built when format == "txt" ->
        conn |> put_resp_content_type("text/plain") |> send_resp(200, built.text_body)

      %Swoosh.Email{} = built ->
        conn |> put_resp_content_type("text/html") |> send_resp(200, built.html_body)
    end
  end

  defp split_format(email) do
    case Path.extname(email) do
      ".txt" -> {Path.rootname(email), "txt"}
      _ -> {email, "html"}
    end
  end
end
