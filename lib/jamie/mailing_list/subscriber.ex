defmodule Jamie.MailingList.Subscriber do
  @moduledoc """
  Someone on the mailing list, or on their way onto it.

  `status` is `:pending` until they follow the confirmation email,
  `:confirmed` after, and `:suspended` when too many soft bounces mean
  mail to them should stop for now.
  """
  use Ecto.Schema
  import Ecto.Changeset

  alias Jamie.MailingList

  @statuses [:pending, :confirmed, :suspended]

  @primary_key {:id, :binary_id, autogenerate: true}

  schema "subscribers" do
    field :email, :string
    field :everything, :boolean, default: false
    field :worlds, {:array, :string}, default: []
    field :frequency, Ecto.Enum, values: MailingList.frequencies()
    field :status, Ecto.Enum, values: @statuses, default: :pending

    field :confirm_token_hash, :binary, redact: true
    field :confirm_sent_at, :utc_datetime_usec
    field :confirmed_at, :utc_datetime_usec
    field :consent_notice_version, :string

    field :last_sent_at, :utc_datetime_usec
    field :soft_bounce_count, :integer, default: 0

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  What a subscriber chooses for themselves, on sign-up or when managing
  their subscription later. Everything else is set by the system.
  """
  def preferences_changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:everything, :worlds, :frequency])
    |> validate_required([:frequency])
    |> update_change(:worlds, &Enum.uniq/1)
    |> validate_subset(:worlds, MailingList.worlds())
    |> validate_something_chosen()
  end

  @doc """
  A new sign-up: the email plus their preferences.
  """
  def signup_changeset(subscriber, attrs) do
    subscriber
    |> cast(attrs, [:email])
    |> update_change(:email, &String.trim/1)
    |> validate_required([:email])
    |> validate_format(:email, ~r/^[^@,;\s]+@[^@,;\s]+\.[^@,;\s]+$/,
      message: "doesn't look like an email address"
    )
    |> validate_length(:email, max: 254)
    |> unique_constraint(:email)
    |> preferences_changeset(attrs)
  end

  # "everything" covers every world, so ticking it is enough on its own
  defp validate_something_chosen(changeset) do
    if get_field(changeset, :everything) or get_field(changeset, :worlds) != [] do
      changeset
    else
      add_error(changeset, :worlds, "pick at least one world, or everything")
    end
  end
end
