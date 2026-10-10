defmodule JamieWeb.PostmarkWebhookControllerTest do
  # not async: one test takes the credentials away
  use JamieWeb.ConnCase, async: false

  alias Jamie.MailingList.EmailEvent

  @delivery %{
    "RecordType" => "Delivery",
    "MessageID" => "msg-1",
    "Recipient" => "reader@example.com",
    "DeliveredAt" => "2026-10-10T08:00:00Z"
  }

  defp authed(conn, password \\ "test-webhook-password") do
    put_req_header(conn, "authorization", Plug.BasicAuth.encode_basic_auth("postmark", password))
  end

  test "with the right credentials the event is recorded", %{conn: conn} do
    conn = conn |> authed() |> post(~p"/webhooks/postmark", @delivery)

    assert response(conn, 200)
    assert Jamie.Repo.aggregate(EmailEvent, :count) == 1
  end

  test "wrong or missing credentials are refused", %{conn: conn} do
    assert conn |> authed("guess") |> post(~p"/webhooks/postmark", @delivery) |> response(401)
    assert build_conn() |> post(~p"/webhooks/postmark", @delivery) |> response(401)
    assert Jamie.Repo.aggregate(EmailEvent, :count) == 0
  end

  test "with no credentials configured it refuses everything", %{conn: conn} do
    config = Application.get_env(:jamie, :postmark_webhook)
    Application.put_env(:jamie, :postmark_webhook, username: nil, password: nil)
    on_exit(fn -> Application.put_env(:jamie, :postmark_webhook, config) end)

    assert conn |> authed() |> post(~p"/webhooks/postmark", @delivery) |> response(401)
  end

  test "a payload it can't read is a 422, so Postmark doesn't retry", %{conn: conn} do
    assert conn |> authed() |> post(~p"/webhooks/postmark", %{"nope" => 1}) |> response(422)
  end
end
