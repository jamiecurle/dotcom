defmodule Jamie.Blog.Note do
  use Ecto.Schema
  import Ecto.Changeset
  alias Jamie.Tags.Tag

  @type t :: %__MODULE__{
          id: integer() | nil,
          status: :draft | :published | :hidden,
          title: String.t() | nil,
          markdown: String.t() | nil,
          html: String.t() | nil,
          published_on: Date.t() | nil,
          edited_on: Date.t() | nil,
          inserted_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @statuses [:draft, :published, :hidden]

  @required_fields [:markdown, :title, :status]
  @optional_fields []

  schema "blog_notes" do
    field :status, Ecto.Enum, values: @statuses, default: :draft
    field :title, :string
    field :markdown, :string
    field :html, :string
    field :published_on, :date
    field :edited_on, :date

    timestamps(type: :utc_datetime_usec)

    many_to_many :tags, Tag, join_through: "tags_notes"
  end

  def statuses, do: @statuses

  @doc false
  def changeset(note, attrs) do
    note
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> Jamie.Markdown.to_html!()
    |> published_on()
  end

  defp published_on(changeset) do
    case get_change(changeset, :status) do
      :published ->
        put_change(changeset, :published_on, Date.utc_today())

      _ ->
        changeset
    end
  end
end
