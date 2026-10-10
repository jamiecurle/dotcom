defmodule Jamie.MailingList.DigestSend do
  @moduledoc """
  A digest that went out. See `Jamie.MailingList.Digests`.
  """
  use Ecto.Schema

  schema "digest_sends" do
    field :period, :string
    field :frequency, Ecto.Enum, values: [:daily, :weekly, :monthly]
    field :post_ids, {:array, :integer}, default: []
    field :message_id, :string
    field :sent_at, :utc_datetime_usec

    belongs_to :subscriber, Jamie.MailingList.Subscriber, type: :binary_id

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
