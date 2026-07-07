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

  @default_bookmark_attrs [
    title: "Some bookmark",
    url: "https://example.com",
    description: "A lovely bookmark",
    favicon: "https://example.com/favicon.ico",
    preview: "https://example.com/preview.png"
  ]

  def bookmark_attrs(opts \\ []) do
    @default_bookmark_attrs
    |> Keyword.merge(opts)
    |> Map.new()
  end

  @doc """
  Generate a bookmark.
  """
  def bookmark_fixture(attrs \\ %{}) do
    {:ok, bookmark} =
      attrs
      |> Enum.into(bookmark_attrs())
      |> Jamie.Content.create_bookmark()

    bookmark
  end
end
