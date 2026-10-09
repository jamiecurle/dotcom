defmodule Jamie.Content.PostSuggestion do
  @moduledoc """
  A proposed find-and-replace edit to a post's markdown, filed by Claude over
  MCP and waiting for a human to accept or reject it in the office.

  `old_string` must appear exactly once in the post when the suggestion is
  filed *and* again when it is accepted. If the post has moved on in between,
  the suggestion is marked `:stale` rather than guessed at.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @statuses [:pending, :accepted, :rejected, :stale]

  schema "post_suggestions" do
    field :old_string, :string
    field :new_string, :string
    field :reason, :string
    field :status, Ecto.Enum, values: @statuses, default: :pending
    field :resolved_at, :utc_datetime_usec

    belongs_to :post, Jamie.Content.Post

    timestamps(type: :utc_datetime_usec)
  end

  @doc """
  Changeset for a new suggestion. `post_id` is set by the caller, not cast.

  `empty_values: [nil]` keeps `""` as a real value: an empty `new_string` is
  a deletion, and whitespace matters in markdown so nothing is trimmed.
  """
  def create_changeset(suggestion, attrs) do
    suggestion
    |> cast(attrs, [:old_string, :new_string, :reason], empty_values: [nil])
    |> validate_present(:old_string)
    |> validate_present(:new_string)
    |> validate_length(:old_string, min: 1)
    |> validate_length(:reason, max: 2_000)
    |> validate_different()
    |> foreign_key_constraint(:post_id)
  end

  def resolve_changeset(suggestion, status) when status in [:accepted, :rejected, :stale] do
    change(suggestion, status: status, resolved_at: DateTime.utc_now())
  end

  # validate_required/2 trims whitespace, which would wrongly reject an edit
  # that only touches spaces or newlines, so check for nil ourselves.
  defp validate_present(changeset, field) do
    if is_nil(get_field(changeset, field)),
      do: add_error(changeset, field, "can't be blank"),
      else: changeset
  end

  defp validate_different(changeset) do
    if get_field(changeset, :old_string) == get_field(changeset, :new_string),
      do: add_error(changeset, :new_string, "must differ from old_string"),
      else: changeset
  end
end
