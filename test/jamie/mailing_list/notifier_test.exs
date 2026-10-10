defmodule Jamie.MailingList.NotifierTest do
  use ExUnit.Case, async: true

  alias Jamie.MailingList.Notifier

  @subscriber %{id: "4f1c", email: "reader@example.com"}

  defp urls do
    fn
      {:manage, id} -> "https://jamie.test/subscribe/#{id}"
      {:one_click, id} -> "https://jamie.test/subscribe/#{id}/unsubscribe"
      {:post, slug} -> "https://jamie.test/posts/#{slug}"
    end
  end

  defp posts do
    [
      %{title: "Oaks", description: "On oaks & <ash>", slug: "oaks"},
      %{title: "Hazel", description: nil, slug: "hazel"}
    ]
  end

  # inline styles only: nothing an inbox would fetch, so nothing to track
  defp refute_remote_resources(html) do
    refute html =~ "<img"
    refute html =~ "<link"
    refute html =~ "<script"
    refute html =~ "url("
  end

  describe "digest_email/4" do
    test "has every post, in both halves, and the ways out" do
      email = Notifier.digest_email(@subscriber, posts(), :weekly, urls())

      assert email.subject == "2 new posts from jamiecurle.com, this week"

      for body <- [email.html_body, email.text_body] do
        assert body =~ "https://jamie.test/posts/oaks"
        assert body =~ "https://jamie.test/posts/hazel"
        assert body =~ "https://jamie.test/subscribe/4f1c"
      end

      assert email.html_body =~ "New writing, this week"

      assert email.headers["List-Unsubscribe"] ==
               "<https://jamie.test/subscribe/4f1c/unsubscribe>"

      refute_remote_resources(email.html_body)
    end

    test "escapes what posts say in the HTML" do
      email = Notifier.digest_email(@subscriber, posts(), :daily, urls())

      assert email.html_body =~ "On oaks &amp; &lt;ash&gt;"
      refute email.html_body =~ "<ash>"
    end

    test "a single post is the subject" do
      email = Notifier.digest_email(@subscriber, Enum.take(posts(), 1), :monthly, urls())
      assert email.subject == "Oaks"
    end
  end

  describe "confirmation_email/2" do
    test "carries the confirm link and no manage link, since there's nothing to manage yet" do
      email = Notifier.confirmation_email(@subscriber, "https://jamie.test/confirm/abc")

      for body <- [email.html_body, email.text_body] do
        assert body =~ "https://jamie.test/confirm/abc"
        assert body =~ "Nothing more will be sent unless you confirm"
        refute body =~ "/subscribe/4f1c"
      end

      refute_remote_resources(email.html_body)
    end
  end

  test "every email invites a reply, in both halves" do
    emails = [
      Notifier.digest_email(@subscriber, posts(), :weekly, urls()),
      Notifier.confirmation_email(@subscriber, "https://jamie.test/confirm/abc"),
      Notifier.already_subscribed_email(@subscriber, "https://jamie.test/subscribe/4f1c")
    ]

    for email <- emails, body <- [email.html_body, email.text_body] do
      assert body =~ "Feel free to hit reply"
    end
  end

  describe "already_subscribed_email/2" do
    test "points at the manage page, in both halves" do
      email = Notifier.already_subscribed_email(@subscriber, "https://jamie.test/subscribe/4f1c")

      for body <- [email.html_body, email.text_body] do
        assert body =~ "https://jamie.test/subscribe/4f1c"
        assert body =~ "unsubscribe"
      end

      refute_remote_resources(email.html_body)
    end
  end
end
