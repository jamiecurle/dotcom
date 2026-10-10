defmodule Jamie.MailingList.StatsTest do
  use Jamie.DataCase, async: true

  alias Jamie.MailingList.{Stats, Subscriber, Webhooks}

  defp subscriber(attrs) do
    Repo.insert!(
      struct(%Subscriber{email: "a@example.com", frequency: :weekly, status: :confirmed}, attrs)
    )
  end

  defp delivery(n) do
    Webhooks.handle(%{
      "RecordType" => "Delivery",
      "MessageID" => "msg-#{n}",
      "Recipient" => "r#{n}@example.com",
      "DeliveredAt" => DateTime.to_iso8601(DateTime.utc_now())
    })
  end

  defp bounce(type, n) do
    Webhooks.handle(%{
      "RecordType" => if(type == "SpamComplaint", do: "SpamComplaint", else: "Bounce"),
      "ID" => n,
      "Type" => type,
      "Email" => "b#{n}@example.com",
      "BouncedAt" => DateTime.to_iso8601(DateTime.utc_now())
    })
  end

  test "subscribers are counted by status, frequency and world" do
    subscriber(email: "a@example.com", worlds: ["treeworld", "foodworld"], frequency: :daily)
    subscriber(email: "b@example.com", everything: true)
    subscriber(email: "c@example.com", worlds: ["treeworld"], status: :pending)

    stats = Stats.subscribers()

    assert stats.by_status == %{confirmed: 2, pending: 1}
    assert stats.by_frequency == %{daily: 1, weekly: 1}
    # pending sign-ups don't count towards worlds yet
    assert stats.by_world["treeworld"] == 1
    assert stats.by_world["everything"] == 1
    assert stats.by_world["techworld"] == 0
  end

  test "rates are judged against the providers' limits" do
    for n <- 1..96, do: delivery(n)
    for n <- 1..3, do: bounce("HardBounce", n)
    bounce("SoftBounce", 4)

    summary = Stats.summary(30)

    assert summary.delivered == 96
    assert summary.hard_bounces == 3
    assert summary.soft_bounces == 1
    # 4 of 100 attempted: past 2%, short of 5%
    assert summary.bounce_rate == 0.04
    assert summary.bounce_health == :warn
    assert summary.complaint_health == :ok

    bounce("SpamComplaint", 5)
    # 1 complaint in 96 deliveries is far past 0.3%
    assert Stats.summary(30).complaint_health == :bad
  end

  test "no mail means no rate, not a division by zero" do
    assert %{bounce_rate: nil, complaint_rate: nil, bounce_health: :ok} = Stats.summary(30)
  end

  test "daily has one row per day, today last" do
    delivery(1)
    days = Stats.daily(30)

    assert length(days) == 30
    assert %{date: today, delivered: 1} = List.last(days)
    assert today == Date.utc_today()
  end

  test "a subscriber's history is found by address" do
    person = subscriber(email: "b1@example.com", everything: true)
    bounce("SoftBounce", 1)

    assert [%{type: "SoftBounce"}] = Stats.subscriber_events(person)
  end
end
