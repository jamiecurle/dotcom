defmodule Jamie.MailingList.SubscribeTest do
  use Jamie.DataCase, async: true

  import Swoosh.TestAssertions

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber

  @attrs %{"email" => "reader@example.com", "worlds" => ["treeworld"], "frequency" => "weekly"}

  # stands in for the LiveView's url builder, and tells the test the token
  defp urls do
    me = self()

    fn
      {:confirm, token} -> send(me, {:token, token}) && "https://jamie.test/confirm/#{token}"
      {:manage, id} -> "https://jamie.test/subscribe/#{id}"
    end
  end

  defp subscriber, do: Repo.get_by!(Subscriber, email: "reader@example.com")

  # pretend the last email went out a while ago, past the resend limit
  defp age(minutes) do
    subscriber()
    |> Ecto.Changeset.change(
      confirm_sent_at: DateTime.add(DateTime.utc_now(), -minutes, :minute),
      inserted_at: DateTime.add(DateTime.utc_now(), -minutes, :minute)
    )
    |> Repo.update!()
  end

  describe "subscribe/2" do
    test "a new address is pending and sent a confirmation link" do
      assert :ok = MailingList.subscribe(@attrs, urls())

      assert_received {:token, token}
      assert subscriber().status == :pending
      # only the hash is stored
      refute subscriber().confirm_token_hash == token

      assert_email_sent(fn email ->
        assert email.to == [{"", "reader@example.com"}]
        assert email.subject == "Confirm your subscription"
        assert email.text_body =~ "https://jamie.test/confirm/#{token}"
      end)
    end

    test "bad input comes back as a changeset" do
      assert {:error, %Ecto.Changeset{}} =
               MailingList.subscribe(%{@attrs | "email" => "nope"}, urls())

      assert_no_email_sent()
    end

    test "a suppressed address is quietly ignored" do
      {:ok, _} = MailingList.suppress("reader@example.com", :hard_bounce)

      assert :ok = MailingList.subscribe(@attrs, urls())
      assert Repo.aggregate(Subscriber, :count) == 0
      assert_no_email_sent()
    end

    test "signing up again straight away doesn't send again" do
      :ok = MailingList.subscribe(@attrs, urls())
      assert_email_sent()

      assert :ok = MailingList.subscribe(@attrs, urls())
      assert_no_email_sent()
    end

    test "a pending address signing up again later gets a fresh link and new choices" do
      :ok = MailingList.subscribe(@attrs, urls())
      assert_received {:token, first}
      age(20)

      :ok = MailingList.subscribe(%{@attrs | "frequency" => "daily"}, urls())

      assert_received {:token, second}
      refute first == second
      assert subscriber().frequency == :daily
      # the old link no longer works
      assert MailingList.get_pending_by_token(first) == nil
      assert MailingList.get_pending_by_token(second)
    end

    test "a confirmed address is sent its manage link instead" do
      :ok = MailingList.subscribe(@attrs, urls())
      assert_received {:token, token}
      assert_email_sent(subject: "Confirm your subscription")
      {:ok, confirmed} = token |> MailingList.get_pending_by_token() |> MailingList.confirm()
      age(20)

      assert :ok = MailingList.subscribe(%{@attrs | "frequency" => "daily"}, urls())

      assert_email_sent(fn email ->
        assert email.subject == "You're already subscribed"
        assert email.text_body =~ "/subscribe/#{confirmed.id}"
      end)

      # their choices only change from the manage page
      assert subscriber().frequency == :weekly
    end
  end

  describe "confirming" do
    setup do
      :ok = MailingList.subscribe(@attrs, urls())
      assert_received {:token, token}
      %{token: token}
    end

    test "the link finds the pending subscriber", %{token: token} do
      assert %Subscriber{email: "reader@example.com"} = MailingList.get_pending_by_token(token)
      assert MailingList.get_pending_by_token("not-a-token") == nil
    end

    test "confirming records consent and spends the token", %{token: token} do
      {:ok, confirmed} = token |> MailingList.get_pending_by_token() |> MailingList.confirm()

      assert confirmed.status == :confirmed
      assert confirmed.confirmed_at
      assert confirmed.consent_notice_version == "unreleased"
      assert confirmed.confirm_token_hash == nil
      assert MailingList.get_pending_by_token(token) == nil
    end

    test "a link older than 7 days has expired", %{token: token} do
      age(8 * 24 * 60)
      assert MailingList.get_pending_by_token(token) == nil
    end
  end

  describe "purge_unconfirmed/0" do
    test "deletes sign-ups never confirmed after 7 days, and nothing else" do
      :ok = MailingList.subscribe(@attrs, urls())
      age(8 * 24 * 60)

      :ok = MailingList.subscribe(%{@attrs | "email" => "fresh@example.com"}, urls())

      assert MailingList.purge_unconfirmed() == 1
      assert [%{email: "fresh@example.com"}] = Repo.all(Subscriber)
    end
  end
end
