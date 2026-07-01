defmodule Jamie.Tags do
  @moduledoc """
  Context boundary for tags
  """

  alias Jamie.Repo
  alias Jamie.Tags.Tag

  def create_tag(attrs) do
    case changeset_tag(%Tag{}, attrs) do
      %{valid?: true} = changeset -> Repo.insert(changeset)
      changeset -> changeset
    end
  end

  @doc """
  Creates a changeset for a tag
  """
  def changeset_tag(%Tag{} = tag, attrs \\ %{}) do
    Tag.changeset(tag, attrs)
  end
end
