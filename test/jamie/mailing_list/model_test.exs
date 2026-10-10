defmodule Jamie.MailingList.ModelTest do
  use Jamie.DataCase, async: true

  alias Jamie.MailingList
  alias Jamie.MailingList.Subscriber

  defp signup(attrs) do
    %Subscriber{}
    |> Subscriber.signup_changeset(
      Map.merge(
        %{"email" => "reader@example.com", "frequency" => "weekly", "consent" => "true"},
        attrs
      )
    )
  end

  describe "signing up" do
    test "an email, some worlds and a frequency is enough" do
      assert {:ok, subscriber} =
               signup(%{"worlds" => ["treeworld", "foodworld"]}) |> Repo.insert()

      assert subscriber.status == :pending
      assert subscriber.frequency == :weekly
      # the manage link's secret is a v4 uuid
      assert {:ok, _} = Ecto.UUID.cast(subscriber.id)
    end

    test "everything stands in for picking worlds" do
      assert signup(%{"everything" => "true"}).valid?
    end

    test "needs at least one world, or everything" do
      assert %{worlds: ["pick at least one world, or everything"]} = errors_on(signup(%{}))
    end

    test "only the hardcoded worlds" do
      assert %{worlds: ["has an invalid entry"]} =
               errors_on(signup(%{"worlds" => ["treeworld", "spaceworld"]}))
    end

    test "a frequency of daily, weekly or monthly" do
      assert %{frequency: ["is invalid"]} =
               errors_on(signup(%{"everything" => "true", "frequency" => "hourly"}))
    end

    test "rejects things that aren't email addresses" do
      assert %{email: [_]} = errors_on(signup(%{"email" => "nope", "everything" => "true"}))
    end

    test "one subscription per address, whatever its case" do
      {:ok, _} = signup(%{"everything" => "true"}) |> Repo.insert()

      assert {:error, changeset} =
               signup(%{"email" => " Reader@Example.com ", "everything" => "true"})
               |> Repo.insert()

      assert %{email: ["has already been taken"]} = errors_on(changeset)
    end
  end

  describe "get_subscriber/1" do
    test "finds by id, and treats a malformed id as not found" do
      {:ok, subscriber} = signup(%{"everything" => "true"}) |> Repo.insert()

      assert MailingList.get_subscriber(subscriber.id).id == subscriber.id
      assert MailingList.get_subscriber(Ecto.UUID.generate()) == nil
      assert MailingList.get_subscriber("../../etc/passwd") == nil
    end
  end

  describe "suppressions" do
    test "an address can be suppressed without being stored" do
      refute MailingList.suppressed?("gone@example.com")

      {:ok, _} = MailingList.suppress("gone@example.com", :hard_bounce)

      assert MailingList.suppressed?(" Gone@Example.com ")
      refute MailingList.suppressed?("other@example.com")

      # only a hash is kept, never the address
      [row] = Repo.all(Jamie.MailingList.Suppression)
      refute row.email_hash =~ "gone"
      assert byte_size(row.email_hash) == 32
    end

    test "suppressing twice is fine" do
      assert {:ok, _} = MailingList.suppress("gone@example.com", :hard_bounce)
      assert {:ok, _} = MailingList.suppress("gone@example.com", :spam_complaint)
      assert Repo.aggregate(Jamie.MailingList.Suppression, :count) == 1
    end
  end
end
