defmodule JamieWeb.MailingListLive.ConsentTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.MailingList.Subscriber
  alias Jamie.Repo

  # the mailing list is gated, so these run as me
  setup :register_and_log_in_user

  @params %{
    "subscriber" => %{
      "email" => "reader@example.com",
      "everything" => "true",
      "frequency" => "weekly",
      "consent" => "false"
    },
    "cf-turnstile-response" => "pass"
  }

  test "the office shows when someone consented, and to which notice", %{conn: conn} do
    s =
      Repo.insert!(%Subscriber{
        email: "reader@example.com",
        everything: true,
        frequency: :weekly,
        status: :confirmed,
        consented_at: ~U[2026-10-10 16:20:00.000000Z],
        consent_notice_version: "2"
      })

    {:ok, view, _html} = live(conn, ~p"/office/mailing-list?#{[subscriber: s.id]}")
    assert has_element?(view, "#consent-record", "Consented 10 Oct 2026 16:20 UTC")
    assert has_element?(view, "#consent-record", "privacy notice 2")
  end

  test "the box links to the privacy notice, in a new tab", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    assert has_element?(view, "#subscriber-consent[type=checkbox]")
    assert has_element?(view, "#consent-privacy-link[href='/privacy'][target=_blank]")
  end

  test "unticked, it says so and subscribes nobody", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    view |> element("#subscribe-form") |> render_submit(@params)

    assert has_element?(view, "#consent-error", "agree to the privacy notice")
    refute has_element?(view, "#subscribe-sent")
    refute Repo.exists?(Subscriber)
  end

  test "ticked, it subscribes and records the consent", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    params = put_in(@params, ["subscriber", "consent"], "true")
    view |> element("#subscribe-form") |> render_submit(params)

    assert has_element?(view, "#subscribe-sent")
    assert %Subscriber{consented_at: %DateTime{}} = Repo.one!(Subscriber)
  end
end
