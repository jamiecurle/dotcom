defmodule Jamie.MailingList.WebhooksTest do
  use Jamie.DataCase, async: true

  alias Jamie.MailingList
  alias Jamie.MailingList.{EmailEvent, Subscriber, Webhooks}

  @email "reader@example.com"

  setup do
    subscriber =
      Repo.insert!(%Subscriber{
        email: @email,
        everything: true,
        frequency: :weekly,
        status: :confirmed
      })

    %{subscriber: subscriber}
  end

  defp bounce(type, id \\ 1) do
    %{
      "RecordType" => "Bounce",
      "ID" => id,
      "Type" => type,
      "TypeCode" => 1,
      "MessageID" => "msg-1",
      "MessageStream" => "broadcast",
      "Email" => @email,
      "Details" => "550 5.1.1 <Reader@Example.com>: user unknown",
      "Content" => "the whole message, address and all",
      "BouncedAt" => "2026-10-10T12:00:00Z"
    }
  end

  defp gone?(subscriber), do: Repo.get(Subscriber, subscriber.id) == nil

  describe "hard bounces and spam complaints" do
    test "a hard bounce suppresses the address and deletes the subscriber", %{subscriber: s} do
      assert {:ok, %EmailEvent{action: "suppressed"}} = Webhooks.handle(bounce("HardBounce"))

      assert gone?(s)
      assert MailingList.suppressed?(@email)
    end

    test "a spam complaint does the same", %{subscriber: s} do
      complaint = %{bounce("SpamComplaint") | "RecordType" => "SpamComplaint"}
      assert {:ok, %EmailEvent{action: "suppressed"}} = Webhooks.handle(complaint)

      assert gone?(s)
      assert MailingList.suppressed?(@email)
    end

    test "the record keeps the hash, never the address or the message", %{subscriber: s} do
      {:ok, event} = Webhooks.handle(bounce("HardBounce"))

      assert event.email_hash == MailingList.email_hash(@email)
      assert event.type == "HardBounce"
      refute Map.has_key?(event.payload, "Email")
      refute Map.has_key?(event.payload, "Content")
      # the address is blanked inside the server's reply too, whatever its case
      assert event.payload["Details"] == "550 5.1.1 <[recipient]>: user unknown"
      # the subscriber is gone, but the event survives
      assert Repo.reload!(event).subscriber_id == nil
      assert gone?(s)
    end
  end

  describe "soft bounces" do
    test "three in a row suspend the subscriber", %{subscriber: s} do
      assert {:ok, %{action: "counted_soft_bounce"}} = Webhooks.handle(bounce("SoftBounce", 1))
      assert {:ok, %{action: "counted_soft_bounce"}} = Webhooks.handle(bounce("Transient", 2))
      assert {:ok, %{action: "suspended"}} = Webhooks.handle(bounce("DnsError", 3))

      assert %{status: :suspended, soft_bounce_count: 3} = Repo.get!(Subscriber, s.id)
      refute MailingList.suppressed?(@email)
    end

    test "a delivery in between starts the count again", %{subscriber: s} do
      Webhooks.handle(bounce("SoftBounce", 1))
      Webhooks.handle(bounce("SoftBounce", 2))

      delivery = %{
        "RecordType" => "Delivery",
        "MessageID" => "msg-2",
        "Recipient" => @email,
        "DeliveredAt" => "2026-10-11T08:00:00Z"
      }

      assert {:ok, %{action: "reset_soft_bounces"}} = Webhooks.handle(delivery)
      assert {:ok, %{action: "counted_soft_bounce"}} = Webhooks.handle(bounce("SoftBounce", 3))
      assert %{status: :confirmed, soft_bounce_count: 1} = Repo.get!(Subscriber, s.id)
    end
  end

  describe "unsubscribes and Postmark's own suppressions" do
    test "an unsubscribe reply deletes without suppressing", %{subscriber: s} do
      assert {:ok, %{action: "deleted"}} = Webhooks.handle(bounce("Unsubscribe"))
      assert gone?(s)
      refute MailingList.suppressed?(@email)
    end

    test "Postmark suppressing the address mirrors its reason", %{subscriber: s} do
      change = %{
        "RecordType" => "SubscriptionChange",
        "MessageID" => "msg-1",
        "Recipient" => @email,
        "ChangedAt" => "2026-10-10T12:00:00Z",
        "SuppressSending" => true,
        "SuppressionReason" => "ManualSuppression"
      }

      assert {:ok, %{action: "deleted"}} = Webhooks.handle(change)
      assert gone?(s)
      refute MailingList.suppressed?(@email)
    end

    test "reactivation is only recorded" do
      change = %{
        "RecordType" => "SubscriptionChange",
        "Recipient" => @email,
        "SuppressSending" => false
      }

      assert {:ok, %{action: "recorded"}} = Webhooks.handle(change)
    end
  end

  test "a retried webhook is acted on once", %{subscriber: s} do
    Webhooks.handle(bounce("SoftBounce", 7))
    assert {:ok, :duplicate} = Webhooks.handle(bounce("SoftBounce", 7))

    assert %{soft_bounce_count: 1} = Repo.get!(Subscriber, s.id)
    assert Repo.aggregate(EmailEvent, :count) == 1
  end

  test "events about addresses we don't know are still recorded" do
    other = %{bounce("HardBounce") | "Email" => "stranger@example.com"}

    assert {:ok, %{action: "suppressed", subscriber_id: nil}} = Webhooks.handle(other)
    assert MailingList.suppressed?("stranger@example.com")
  end

  test "something without a RecordType is turned away" do
    assert {:error, :unrecognised} = Webhooks.handle(%{"hello" => "there"})
  end

  test "old events are purged after the retention period" do
    {:ok, event} = Webhooks.handle(bounce("SoftBounce"))

    event
    |> Ecto.Changeset.change(inserted_at: DateTime.add(DateTime.utc_now(), -401, :day))
    |> Repo.update!()

    assert MailingList.purge_old_email_events() == 1
  end
end
