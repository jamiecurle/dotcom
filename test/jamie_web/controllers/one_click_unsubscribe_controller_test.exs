defmodule JamieWeb.OneClickUnsubscribeControllerTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.MailingList.Subscriber
  alias Jamie.Repo

  defp subscriber do
    Repo.insert!(%Subscriber{
      email: "reader@example.com",
      everything: true,
      frequency: :weekly,
      status: :confirmed
    })
  end

  test "a mail provider's POST unsubscribes, with no session or token", %{conn: conn} do
    reader = subscriber()

    conn =
      post(conn, ~p"/subscribe/#{reader.id}/unsubscribe", %{
        "List-Unsubscribe" => "One-Click"
      })

    assert response(conn, 200)
    assert Repo.get(Subscriber, reader.id) == nil
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
  end

  test "an unknown or malformed id gets the same 200", %{conn: conn} do
    assert conn |> post(~p"/subscribe/#{Ecto.UUID.generate()}/unsubscribe") |> response(200)
    assert build_conn() |> post("/subscribe/nope/unsubscribe") |> response(200)
  end

  test "a person opening the link goes to the manage page", %{conn: conn} do
    reader = subscriber()
    conn = get(conn, ~p"/subscribe/#{reader.id}/unsubscribe")
    assert redirected_to(conn) == ~p"/subscribe/#{reader.id}"
  end
end
