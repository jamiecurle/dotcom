defmodule JamieWeb.OfficeLive.MailingListPreviewTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  test "needs a login, raw emails included", %{conn: conn} do
    assert {:error, {:redirect, _}} = live(conn, ~p"/office/mailing-list/preview")
    assert conn |> get(~p"/office/mailing-list/emails/digest") |> redirected_to()
  end

  describe "signed in" do
    setup :register_and_log_in_user

    setup do
      {:ok, post} =
        Content.create_post(
          ContentFixtures.post_attrs(title: "Coppicing hazel", status: :published)
        )

      %{post: post}
    end

    test "serves each email raw, as HTML and as text", %{conn: conn, post: post} do
      html = conn |> get(~p"/office/mailing-list/emails/digest") |> html_response(200)
      assert html =~ "Coppicing hazel"
      assert html =~ "/posts/#{post.slug}"

      text = conn |> get(~p"/office/mailing-list/emails/digest.txt") |> response(200)
      assert text =~ "Coppicing hazel"
      refute text =~ "<"

      for email <- ["confirmation", "already-subscribed"] do
        assert conn |> get(~p"/office/mailing-list/emails/#{email}") |> html_response(200)
        assert conn |> get(~p"/office/mailing-list/emails/#{email <> ".txt"}") |> response(200)
      end
    end

    test "the digest's wording follows the frequency", %{conn: conn} do
      html =
        conn
        |> get(~p"/office/mailing-list/emails/digest?#{[frequency: "daily"]}")
        |> html_response(200)

      assert html =~ "New writing, today"
    end

    test "an email that isn't one is not found", %{conn: conn} do
      assert conn |> get(~p"/office/mailing-list/emails/nope") |> response(404)
      assert conn |> get(~p"/office/mailing-list/emails/digest?frequency=hourly") |> response(404)
    end

    test "frames the email and shows its text, switching between them", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list/preview")

      assert has_element?(view, "#preview-html[src*='/emails/digest']")
      assert has_element?(view, "#preview-text", "Coppicing hazel")
      assert has_element?(view, "#preview-subject", "Coppicing hazel")

      view |> element("#preview-confirmation") |> render_click()

      assert has_element?(view, "#preview-html[src*='/emails/confirmation']")
      assert has_element?(view, "#preview-subject", "Confirm your subscription")
      refute has_element?(view, "#send-test-digest")
    end

    test "sends a test digest to whoever's signed in", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list/preview")

      view |> element("#send-test-digest") |> render_click()

      # logging in sent its own email first
      assert_received {:email, %{subject: "[Test] " <> _} = email}
      assert email.to == [{"", user.email}]
      assert email.subject == "[Test] Coppicing hazel"
      assert email.provider_options.message_stream == "broadcast"
    end

    test "is linked from the mailing list page", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/office/mailing-list")
      assert has_element?(view, "#preview-emails-link[href='/office/mailing-list/preview']")
    end

    test "the mailing list page shows how each digest went", %{conn: conn} do
      Jamie.Repo.insert!(%Jamie.MailingList.DigestSend{
        period: "weekly:2026-10-16",
        frequency: :weekly,
        message_id: "m1",
        sent_at: DateTime.utc_now()
      })

      {:ok, view, _html} = live(conn, ~p"/office/mailing-list")
      assert has_element?(view, "#digest-send-weekly-2026-10-16")
    end
  end
end
