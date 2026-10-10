defmodule Jamie.MailingList.EmailEvent do
  @moduledoc """
  One thing Postmark told us about mail we sent. See
  `Jamie.MailingList.Webhooks` for how each kind is handled.
  """
  use Ecto.Schema

  schema "email_events" do
    field :record_type, :string
    field :type, :string
    field :type_code, :integer
    field :message_id, :string
    field :message_stream, :string
    field :email_hash, :binary
    field :occurred_at, :utc_datetime_usec
    field :action, :string
    field :payload, :map
    field :dedupe_key, :string

    belongs_to :subscriber, Jamie.MailingList.Subscriber, type: :binary_id

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
