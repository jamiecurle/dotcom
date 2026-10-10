defmodule Jamie.MailingList.StatsSendsTest do
  use Jamie.DataCase, async: true

  alias Jamie.MailingList.{DigestSend, Stats, Webhooks}

  defp sent(period, message_id, minutes_ago \\ 0) do
    Repo.insert!(%DigestSend{
      period: period,
      frequency: period |> String.split(":") |> hd() |> String.to_existing_atom(),
      message_id: message_id,
      sent_at: DateTime.add(DateTime.utc_now(), -minutes_ago, :minute)
    })
  end

  defp event(record_type, type, message_id) do
    Webhooks.handle(%{
      "RecordType" => record_type,
      "ID" => System.unique_integer([:positive]),
      "Type" => type,
      "MessageID" => message_id,
      "Recipient" => "r@example.com",
      "Email" => "r@example.com",
      "DeliveredAt" => DateTime.to_iso8601(DateTime.utc_now()),
      "BouncedAt" => DateTime.to_iso8601(DateTime.utc_now())
    })
  end

  test "counts each period's sends and what came back for them, newest first" do
    for n <- 1..4, do: sent("weekly:2026-10-16", "w#{n}")
    sent("daily:2026-10-15", "d1", 60 * 24)

    event("Delivery", nil, "w1")
    event("Delivery", nil, "w2")
    event("Bounce", "HardBounce", "w3")
    event("Bounce", "SoftBounce", "w4")
    event("SpamComplaint", "SpamComplaint", "w1")
    # not a digest: a confirmation, say
    event("Delivery", nil, "someone-else")

    assert [weekly, daily] = Stats.sends(10)

    assert %{period: "weekly:2026-10-16", sent: 4, delivered: 2} = weekly
    assert %{hard_bounces: 1, soft_bounces: 1, complaints: 1} = weekly
    assert weekly.bounce_rate == 0.5
    assert weekly.bounce_health == :bad
    assert weekly.complaint_rate == 0.25

    assert %{period: "daily:2026-10-15", sent: 1, delivered: 0, bounce_rate: +0.0} = daily
  end

  test "nothing sent, nothing to show" do
    assert Stats.sends(10) == []
  end
end
