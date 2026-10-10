defmodule JamieWeb.MailingListLive.ConfirmTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.MailingList

  setup :register_and_log_in_user

  setup do
    me = self()

    :ok =
      MailingList.subscribe(
        %{
          "email" => "reader@example.com",
          "everything" => "true",
          "frequency" => "daily",
          "consent" => "true"
        },
        fn {:confirm, token} -> send(me, {:token, token}) && "url" end
      )

    assert_received {:token, token}
    %{token: token}
  end

  test "opening the link alone confirms nothing", %{conn: conn, token: token} do
    {:ok, view, _html} = live(conn, ~p"/subscribe/confirm/#{token}")

    assert has_element?(view, "#subscribe-confirm", "reader@example.com")
    assert MailingList.get_pending_by_token(token)
  end

  test "pressing confirm does", %{conn: conn, token: token} do
    {:ok, view, _html} = live(conn, ~p"/subscribe/confirm/#{token}")

    view |> element("#confirm-subscription") |> render_click()

    assert has_element?(view, "#subscribe-confirmed")
    assert MailingList.get_pending_by_token(token) == nil
    assert %{status: :confirmed} = Jamie.Repo.one!(Jamie.MailingList.Subscriber)
  end

  test "a wrong or spent link says it has expired", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe/confirm/nope")
    assert has_element?(view, "#subscribe-expired")
  end

  test "secret-bearing paths aren't logged" do
    assert JamieWeb.Endpoint.log_level(%Plug.Conn{path_info: ["subscribe", "confirm", "x"]}) ==
             false

    assert JamieWeb.Endpoint.log_level(%Plug.Conn{path_info: ["subscribe"]}) == :info
  end
end
