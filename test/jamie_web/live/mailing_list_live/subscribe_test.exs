defmodule JamieWeb.MailingListLive.SubscribeTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias Jamie.MailingList.Subscriber
  alias Jamie.Repo

  # the mailing list is gated, so these run as me
  setup :register_and_log_in_user

  # signing in sends its own email; start each test with an empty mailbox
  setup do
    flush_emails()
    :ok
  end

  defp flush_emails do
    receive do
      {:email, _} -> flush_emails()
    after
      0 -> :ok
    end
  end

  @params %{
    "subscriber" => %{
      "email" => "reader@example.com",
      "everything" => "false",
      "worlds" => ["treeworld", "foodworld"],
      "frequency" => "monthly"
    },
    "cf-turnstile-response" => "pass"
  }

  test "the form offers every world, everything and three frequencies", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    assert has_element?(view, "#subscriber-everything")

    for world <- Jamie.MailingList.worlds() do
      assert has_element?(view, "#subscriber-world-#{world}")
    end

    for frequency <- ~w(daily weekly monthly) do
      assert has_element?(view, "#subscriber-frequency-#{frequency}")
    end

    assert has_element?(view, "#turnstile[phx-hook=Turnstile][data-sitekey=test-site-key]")
  end

  test "subscribing ends in check your inbox", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    view |> element("#subscribe-form") |> render_submit(@params)

    assert has_element?(view, "#subscribe-sent")
    assert %{worlds: ["treeworld", "foodworld"], frequency: :monthly} = Repo.one!(Subscriber)
    assert_email_sent(subject: "Confirm your subscription")
  end

  test "failing the bot check sends nothing", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    view
    |> element("#subscribe-form")
    |> render_submit(%{@params | "cf-turnstile-response" => "bot"})

    assert has_element?(view, "#bot-check-failed")
    refute has_element?(view, "#subscribe-sent")
    assert Repo.aggregate(Subscriber, :count) == 0
    assert_no_email_sent()
  end

  test "picking nothing says so", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    params = put_in(@params, ["subscriber", "worlds"], [])
    view |> element("#subscribe-form") |> render_submit(params)

    assert has_element?(view, "#subscribe-worlds .error", "pick at least one world")
    refute has_element?(view, "#subscribe-sent")
  end

  test "ticking everything stands in for the worlds", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")

    params =
      @params
      |> put_in(["subscriber", "everything"], "true")
      |> put_in(["subscriber", "worlds"], [])

    view |> element("#subscribe-form") |> render_change(params)
    assert has_element?(view, "#subscriber-world-treeworld[disabled]")

    view |> element("#subscribe-form") |> render_submit(params)
    assert %{everything: true} = Repo.one!(Subscriber)
  end
end
