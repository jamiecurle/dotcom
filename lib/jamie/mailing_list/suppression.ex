defmodule Jamie.MailingList.Suppression do
  @moduledoc """
  An address that must never be mailed again, kept only as a keyed hash.
  See `Jamie.MailingList.suppress/2`.
  """
  use Ecto.Schema

  @reasons [:hard_bounce, :spam_complaint, :manual]

  schema "suppressions" do
    field :email_hash, :binary
    field :reason, Ecto.Enum, values: @reasons

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def reasons, do: @reasons
end
