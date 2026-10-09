defmodule JamieWeb.ContentLive.TagsTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Tags

  defp create_post(title, status) do
    {:ok, post} =
      ContentFixtures.post_attrs(title: title, status: status) |> Content.create_post()

    post
  end

  setup do
    tagged = create_post("Tagged", :published)
    untagged = create_post("Untagged", :published)
    draft = create_post("Draft", :draft)

    Tags.set_post_tags(tagged, ["Woodland"])
    Tags.set_post_tags(draft, ["Woodland", "Secret"])

    %{tagged: tagged, untagged: untagged, draft: draft}
  end

  test "a post shows its tags in the masthead, linking to the tag page", %{
    conn: conn,
    tagged: tagged
  } do
    {:ok, view, _html} = live(conn, ~p"/posts/#{tagged.slug}")

    assert has_element?(
             view,
             "header.masthead ul.post-tags a#tag-woodland[href='/tags/woodland']"
           )
  end

  test "a post without tags shows no tag list", %{conn: conn, untagged: untagged} do
    {:ok, view, _html} = live(conn, ~p"/posts/#{untagged.slug}")

    refute has_element?(view, "ul.post-tags")
  end

  test "a tag page lists only the tag's published posts", %{
    conn: conn,
    tagged: tagged,
    untagged: untagged,
    draft: draft
  } do
    {:ok, view, _html} = live(conn, ~p"/tags/woodland")

    assert has_element?(view, "h1.page-title", "woodland")
    assert has_element?(view, "#post-#{tagged.id}")
    refute has_element?(view, "#post-#{untagged.id}")
    refute has_element?(view, "#post-#{draft.id}")
  end

  test "a tag with nothing published is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/tags/secret") end
  end

  test "an unknown tag is a 404", %{conn: conn} do
    assert_error_sent 404, fn -> get(conn, ~p"/tags/nope") end
  end
end
