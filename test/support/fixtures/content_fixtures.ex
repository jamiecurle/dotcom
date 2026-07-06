defmodule Jamie.Support.ContentFixtures do
  @moduledoc """
  Fixtures for the content context.
  """

  @default_note_attrs [
    title: "Basic note",
    markdown: """
    # Hello, World!
    Here's a list of some great ideas
    * test the thing
    * deploy the thing
    * use the thing
    """,
    status: :draft
  ]

  def note_attrs(opts \\ []) do
    @default_note_attrs
    |> Keyword.merge(opts)
    |> Map.new()

    # |> IO.inspect(label: "attrs")
  end

  @default_post_attrs [
    title: "Basic post",
    description: "A lovely description",
    markdown: """
    # Hello, World!
    Here's a list of some great ideas
    * test the thing
    * deploy the thing
    * use the thing
    """,
    status: :draft
  ]

  def post_attrs(opts \\ []) do
    @default_post_attrs
    |> Keyword.merge(opts)
    |> Map.new()
  end

  @doc """
  Generate a bookmark.
  """
  def bookmark_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        title: "some title",
        url: "some url"
      })

    {:ok, bookmark} = Jamie.Content.create_bookmark(scope, attrs)
    bookmark
  end
end
