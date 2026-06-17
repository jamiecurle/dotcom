defmodule Jamie.Support.BlogFixtures do
  @moduledoc """
  Fixtures for the blog context.
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
    title: "Basic blog post",
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
end
