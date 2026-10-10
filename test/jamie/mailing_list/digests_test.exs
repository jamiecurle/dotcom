defmodule Jamie.MailingList.DigestsTest do
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  import Swoosh.TestAssertions

  alias Jamie.Content
  alias Jamie.MailingList.{Digests, DigestSend, Subscriber}
  alias Jamie.Support.ContentFixtures
  alias Jamie.Workers.{DigestDeliver, DigestSchedule}

  defp post(title, tags, status \\ :published) do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(title: title, status: status))
    {:ok, _} = Jamie.Tags.set_post_tags(post, tags)
    post
  end

  defp subscriber(attrs) do
    Repo.insert!(
      struct(
        %Subscriber{
          email: "reader@example.com",
          frequency: :weekly,
          status: :confirmed,
          confirmed_at: DateTime.add(DateTime.utc_now(), -1, :day)
        },
        attrs
      )
    )
  end

  defp urls do
    &JamieWeb.MailingListUrls.url_for/1
  end

  describe "posts_for/1" do
    test "only posts in their worlds, oldest first" do
      trees = post("Oaks", ["treeworld"])
      _tech = post("Elixir", ["techworld"])
      food = post("Bread", ["foodworld", "makerworld"])

      reader = subscriber(worlds: ["treeworld", "makerworld"])

      assert Enum.map(Digests.posts_for(reader), & &1.id) == [trees.id, food.id]
    end

    test "everything means every published post, drafts never" do
      post("Oaks", ["treeworld"])
      post("Untagged", [])
      post("Draft", ["treeworld"], :draft)

      reader = subscriber(everything: true)

      assert Digests.posts_for(reader) |> Enum.map(& &1.title) |> Enum.sort() ==
               ["Oaks", "Untagged"]
    end

    test "nothing from before they confirmed" do
      post("Oaks", ["treeworld"])

      reader =
        subscriber(worlds: ["treeworld"], confirmed_at: DateTime.add(DateTime.utc_now(), 2, :day))

      assert Digests.posts_for(reader) == []
    end
  end

  describe "deliver/4" do
    test "emails the posts through the broadcast stream, ready for one-click unsubscribe" do
      post("Oaks", ["treeworld"])
      reader = subscriber(worlds: ["treeworld"])

      assert {:ok, %DigestSend{post_ids: [_]}} =
               Digests.deliver(reader.id, "weekly:2026-10-16", :weekly, urls())

      assert_email_sent(fn email ->
        assert email.subject == "Oaks"
        assert email.text_body =~ "/posts/oaks"
        assert email.text_body =~ "/subscribe/#{reader.id}"
        assert email.headers["List-Unsubscribe"] =~ "/subscribe/#{reader.id}/unsubscribe"
        assert email.headers["List-Unsubscribe-Post"] == "List-Unsubscribe=One-Click"
        assert email.provider_options.message_stream == "broadcast"
        assert email.provider_options.track_opens == false
      end)

      assert Repo.get!(Subscriber, reader.id).last_sent_at
    end

    test "a period's digest only ever goes once" do
      post("Oaks", ["treeworld"])
      reader = subscriber(worlds: ["treeworld"])

      {:ok, _} = Digests.deliver(reader.id, "weekly:2026-10-16", :weekly, urls())
      assert_email_sent()

      assert {:ok, :already_sent} =
               Digests.deliver(reader.id, "weekly:2026-10-16", :weekly, urls())

      assert_no_email_sent()
    end

    test "a post goes in one digest, not every one after" do
      post("Oaks", ["treeworld"])
      reader = subscriber(worlds: ["treeworld"])

      {:ok, _} = Digests.deliver(reader.id, "weekly:2026-10-16", :weekly, urls())

      assert {:ok, :nothing_new} =
               Digests.deliver(reader.id, "weekly:2026-10-23", :weekly, urls())
    end

    test "nothing new means no email" do
      reader = subscriber(worlds: ["treeworld"])
      assert {:ok, :nothing_new} = Digests.deliver(reader.id, "daily:2026-10-11", :daily, urls())
      assert_no_email_sent()
    end

    test "pending, suspended and departed subscribers get nothing" do
      post("Oaks", ["treeworld"])

      for status <- [:pending, :suspended] do
        reader = subscriber(email: "#{status}@example.com", everything: true, status: status)
        assert {:ok, :not_subscribed} = Digests.deliver(reader.id, "daily:x", :daily, urls())
      end

      assert {:ok, :not_subscribed} =
               Digests.deliver(Ecto.UUID.generate(), "daily:x", :daily, urls())

      assert_no_email_sent()
    end
  end

  describe "the schedule" do
    setup do
      config = Application.get_env(:jamie, :mailing_list)
      on_exit(fn -> Application.put_env(:jamie, :mailing_list, config) end)
      %{config: config}
    end

    test "does nothing while the mailing list is off" do
      subscriber(everything: true)
      assert :ok = perform_job(DigestSchedule, %{"frequency" => "weekly"})
      refute_enqueued(worker: DigestDeliver)
    end

    test "queues a digest for each subscriber due", %{config: config} do
      Application.put_env(:jamie, :mailing_list, Keyword.put(config, :enabled, true))
      reader = subscriber(everything: true)
      subscriber(email: "daily@example.com", everything: true, frequency: :daily)

      assert :ok = perform_job(DigestSchedule, %{"frequency" => "weekly"})

      period = Digests.period(:weekly, Digests.today())

      assert [%{args: %{"subscriber_id" => id, "period" => ^period}}] =
               all_enqueued(worker: DigestDeliver)

      assert id == reader.id
    end
  end

  test "periods are named after the frequency and London date" do
    assert Digests.period(:monthly, ~D[2026-10-28]) == "monthly:2026-10-28"
    assert %Date{} = Digests.today()
  end
end
