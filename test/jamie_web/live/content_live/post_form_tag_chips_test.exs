defmodule JamieWeb.ContentLive.PostFormTagChipsTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Tags

  setup :register_and_log_in_user

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs())
    {:ok, _} = Tags.set_post_tags(post, ["elixir", "woodland"])
    %{post: post}
  end

  defp open(conn, post) do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    view
  end

  test "the post's tags show as chips", %{conn: conn, post: post} do
    view = open(conn, post)

    assert has_element?(view, "#tag-elixir")
    assert has_element?(view, "#tag-woodland")
    refute has_element?(view, "#tags-unsaved")
  end

  test "adding tags makes chips but saves nothing until Save Post", %{conn: conn, post: post} do
    view = open(conn, post)

    view |> form("#tag-form", tag: "Trees, elixir") |> render_submit()

    assert has_element?(view, "#tag-trees")
    assert has_element?(view, "#tags-unsaved")
    assert Tags.post_tag_titles(post) == ["elixir", "woodland"]

    view |> form("#editor-form") |> render_submit()

    assert Tags.post_tag_titles(post) == ["elixir", "trees", "woodland"]
    refute has_element?(view, "#tags-unsaved")
  end

  test "typing a comma commits the tag", %{conn: conn, post: post} do
    view = open(conn, post)

    view |> form("#tag-form", tag: "workshop,") |> render_change()

    assert has_element?(view, "#tag-workshop")
  end

  test "chips can be removed, and backspace on an empty input drops the last", %{
    conn: conn,
    post: post
  } do
    view = open(conn, post)

    view |> element("#tag-elixir button") |> render_click()
    refute has_element?(view, "#tag-elixir")

    view |> element("#tag-input") |> render_keydown(%{"key" => "Backspace", "value" => ""})
    refute has_element?(view, "#tag-woodland")

    view |> form("#editor-form") |> render_submit()
    assert Tags.post_tag_titles(post) == []
  end

  test "existing tags are suggested and can be picked", %{conn: conn, post: post} do
    {:ok, _} = Tags.create_tag(%{title: "workshop"})
    view = open(conn, post)

    view |> form("#tag-form", tag: "work") |> render_change()
    assert has_element?(view, "#tag-suggestions", "workshop")

    view |> element("#tag-suggestions button", "workshop") |> render_click()

    assert has_element?(view, "#tag-workshop")
    refute has_element?(view, "#tag-suggestions")
  end

  test "a new post saves its chips", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/new")

    view |> form("#tag-form", tag: "trees") |> render_submit()

    view
    |> form("#editor-form", post: %{title: "Tagged from new", description: "d", markdown: "body"})
    |> render_submit()

    post = Jamie.Repo.get_by!(Content.Post, title: "Tagged from new")
    assert Tags.post_tag_titles(post) == ["trees"]
  end
end
