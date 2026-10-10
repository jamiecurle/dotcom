defmodule Jamie.MailingList.ConsentTest do
  use Jamie.DataCase, async: true

  import Swoosh.TestAssertions

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber

  @attrs %{
    "email" => "reader@example.com",
    "everything" => "true",
    "frequency" => "weekly",
    "consent" => "true"
  }

  defp urls do
    fn
      {:confirm, token} -> "https://jamie.test/confirm/#{token}"
      {:manage, id} -> "https://jamie.test/subscribe/#{id}"
    end
  end

  defp subscriber, do: Repo.get_by!(Subscriber, email: "reader@example.com")

  defp version, do: Application.get_env(:jamie, :mailing_list)[:privacy_notice_version]

  test "signing up records when they agreed, and to which notice" do
    before = DateTime.utc_now()
    assert :ok = MailingList.subscribe(@attrs, urls())

    s = subscriber()
    assert DateTime.compare(s.consented_at, before) in [:gt, :eq]
    assert s.consent_notice_version == version()
  end

  test "without the box ticked nothing is stored and nothing is sent" do
    for consent <- [nil, "false"] do
      attrs =
        if consent, do: %{@attrs | "consent" => consent}, else: Map.delete(@attrs, "consent")

      assert {:error, changeset} = MailingList.subscribe(attrs, urls())
      assert %{consent: [_]} = errors_on(changeset)
    end

    refute Repo.exists?(Subscriber)
    assert_no_email_sent()
  end

  test "the form can't set the consent record itself" do
    forged =
      Map.merge(@attrs, %{
        "consented_at" => "2000-01-01T00:00:00Z",
        "consent_notice_version" => "0"
      })

    assert :ok = MailingList.subscribe(forged, urls())

    s = subscriber()
    assert s.consent_notice_version == version()
    assert s.consented_at.year > 2000
  end

  test "confirming keeps the consent given at sign-up" do
    :ok = MailingList.subscribe(@attrs, urls())
    agreed = subscriber().consented_at

    {:ok, confirmed} = MailingList.confirm(subscriber())
    assert confirmed.consented_at == agreed
  end

  test "a sign-up from before the box existed records consent when confirmed" do
    legacy =
      Repo.insert!(%Subscriber{email: "old@example.com", everything: true, frequency: :weekly})

    {:ok, confirmed} = MailingList.confirm(legacy)
    assert confirmed.consented_at
    assert confirmed.consent_notice_version == version()
  end

  test "someone resubmitting a confirmed address doesn't touch its consent" do
    agreed = ~U[2026-01-01 00:00:00.000000Z]

    Repo.insert!(%Subscriber{
      email: "reader@example.com",
      everything: true,
      frequency: :weekly,
      status: :confirmed,
      consented_at: agreed,
      consent_notice_version: "1"
    })

    assert :ok = MailingList.subscribe(@attrs, urls())

    s = subscriber()
    assert s.consented_at == agreed
    assert s.consent_notice_version == "1"
  end
end
