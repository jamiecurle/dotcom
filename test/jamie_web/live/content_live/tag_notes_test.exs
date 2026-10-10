defmodule JamieWeb.ContentLive.TagNotesTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Tags

  defp create_note(title, status) do
    {:ok, note} =
      ContentFixtures.note_attrs(title: title, status: status) |> Content.create_note()

    note
  end

  defp create_post(title) do
    {:ok, post} =
      ContentFixtures.post_attrs(title: title, status: :published) |> Content.create_post()

    post
  end

  test "a tag page mixes the tag's published posts and notes", %{conn: conn} do
    post = create_post("A post")
    note = create_note("A note", :published)
    draft = create_note("A draft note", :draft)

    Tags.set_post_tags(post, ["Privacy"])
    {:ok, _} = Tags.tag(note, "Privacy")
    {:ok, _} = Tags.tag(draft, "Privacy")

    {:ok, view, _html} = live(conn, ~p"/tags/privacy")

    assert has_element?(view, "#post-#{post.id}[href='/posts/#{post.slug}']")
    assert has_element?(view, "#note-#{note.id}[href='/notes/#{note.id}'] .kind")
    refute has_element?(view, "#post-#{post.id} .kind")
    refute has_element?(view, "#note-#{draft.id}")
  end

  test "a tag with only notes is not a 404", %{conn: conn} do
    note = create_note("Only a note", :published)
    {:ok, _} = Tags.tag(note, "Woodland")

    {:ok, view, _html} = live(conn, ~p"/tags/woodland")

    assert has_element?(view, "#note-#{note.id}")
  end

  test "a tag with only draft notes is a 404", %{conn: conn} do
    draft = create_note("Draft", :draft)
    {:ok, _} = Tags.tag(draft, "Secret")

    assert_error_sent 404, fn -> get(conn, ~p"/tags/secret") end
  end
end
