defmodule JamieWeb.OfficeLive.MailingListTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.MailingList.{Subscriber, Webhooks}
  alias Jamie.Repo

  test "requires login", %{conn: conn} do
    assert {:error, {:redirect, _}} = live(conn, ~p"/office/mailing-list")
  end

  describe "signed in" do
    setup :register_and_log_in_user

    setup do
      subscriber =
        Repo.insert!(%Subscriber{
          email: "reader@example.com",
          worlds: ["treeworld"],
          frequency: :weekly,
          status: :confirmed
        })

      %{subscriber: subscriber}
    end

    defp soft_bounce(id) do
      Webhooks.handle(%{
        "RecordType" => "Bounce",
        "ID" => id,
        "Type" => "SoftBounce",
        "Email" => "reader@example.com",
        "Details" => "mailbox full",
        "BouncedAt" => DateTime.to_iso8601(DateTime.utc_now())
      })
    end

    test "shows the gate, the health numbers and everyone", %{conn: conn, subscriber: s} do
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list")

      assert has_element?(view, "#mailing-list-gate", "Hidden from visitors")
      assert has_element?(view, "#bounce-rate")
      assert has_element?(view, "#complaint-rate")
      assert has_element?(view, "#world-count-treeworld", "1")
      assert has_element?(view, "#subscriber-#{s.id}", "reader@example.com")
    end

    test "webhooks show up without a reload", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list")

      soft_bounce(1)

      assert has_element?(view, "#recent-events", "SoftBounce")
      assert has_element?(view, "#recent-events", "mailbox full")
    end

    test "a subscriber's history opens from the list", %{conn: conn, subscriber: s} do
      soft_bounce(1)
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list")

      view |> element("#subscriber-#{s.id} a") |> render_click()

      assert has_element?(view, "#subscriber-timeline", "reader@example.com")
      assert has_element?(view, "#timeline-events", "SoftBounce")
    end
  end
end
