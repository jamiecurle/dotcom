defmodule JamieWeb.MailingListLive.ManageTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber
  alias Jamie.Repo

  # the mailing list is gated, so these run as me
  setup :register_and_log_in_user

  defp subscriber(status) do
    %Subscriber{
      email: "reader@example.com",
      worlds: ["treeworld"],
      frequency: :weekly,
      status: status
    }
    |> Repo.insert!()
  end

  test "shows the address and current choices", %{conn: conn} do
    subscriber = subscriber(:confirmed)
    {:ok, view, _html} = live(conn, ~p"/subscribe/#{subscriber.id}")

    assert has_element?(view, "header .standfirst", "reader@example.com")
    assert has_element?(view, "#subscriber-world-treeworld[checked]")
    refute has_element?(view, "#subscriber-world-foodworld[checked]")
    assert has_element?(view, "#subscriber-frequency-weekly[checked]")
  end

  test "changing worlds and frequency saves them", %{conn: conn} do
    subscriber = subscriber(:confirmed)
    {:ok, view, _html} = live(conn, ~p"/subscribe/#{subscriber.id}")

    view
    |> element("#manage-form")
    |> render_submit(%{
      "subscriber" => %{
        "everything" => "false",
        "worlds" => ["foodworld", "makerworld"],
        "frequency" => "daily"
      }
    })

    assert has_element?(view, "#manage-saved")

    assert %{worlds: ["foodworld", "makerworld"], frequency: :daily} =
             Repo.get!(Subscriber, subscriber.id)
  end

  test "choosing nothing is refused", %{conn: conn} do
    subscriber = subscriber(:confirmed)
    {:ok, view, _html} = live(conn, ~p"/subscribe/#{subscriber.id}")

    view
    |> element("#manage-form")
    |> render_submit(%{
      "subscriber" => %{"everything" => "false", "worlds" => [""], "frequency" => "daily"}
    })

    assert has_element?(view, "#subscribe-worlds .error")
    refute has_element?(view, "#manage-saved")
    assert %{worlds: ["treeworld"]} = Repo.get!(Subscriber, subscriber.id)
  end

  test "unsubscribing deletes them and the link stops working", %{conn: conn} do
    subscriber = subscriber(:confirmed)
    {:ok, view, _html} = live(conn, ~p"/subscribe/#{subscriber.id}")

    view |> element("#unsubscribe-button") |> render_click()

    assert has_element?(view, "#subscribe-unsubscribed")
    assert Repo.get(Subscriber, subscriber.id) == nil
    assert_error_sent 404, fn -> get(conn, ~p"/subscribe/#{subscriber.id}") end
  end

  test "a suspended subscriber can still manage and leave", %{conn: conn} do
    subscriber = subscriber(:suspended)
    {:ok, view, _html} = live(conn, ~p"/subscribe/#{subscriber.id}")

    assert has_element?(view, "#subscribe-suspended")
    assert has_element?(view, "#unsubscribe-button")
  end

  test "pending, unknown and malformed ids are all the same 404", %{conn: conn} do
    pending = subscriber(:pending)

    for id <- [pending.id, Ecto.UUID.generate(), "not-a-uuid"] do
      assert_error_sent 404, fn -> get(conn, "/subscribe/#{id}") end
    end
  end

  test "the page is never indexed or passed on as a referrer", %{conn: conn} do
    subscriber = subscriber(:confirmed)
    conn = get(conn, ~p"/subscribe/#{subscriber.id}")

    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
    assert get_resp_header(conn, "x-robots-tag") == ["noindex, nofollow"]
  end

  test "the confirmation page gets the same headers", %{conn: conn} do
    conn = get(conn, ~p"/subscribe/confirm/anything")
    assert get_resp_header(conn, "referrer-policy") == ["no-referrer"]
  end

  test "get_manageable/1 only finds confirmed and suspended subscribers" do
    assert MailingList.get_manageable(subscriber(:confirmed).id)
    refute MailingList.get_manageable(Ecto.UUID.generate())
  end
end
