defmodule JamieWeb.SubscribeInviteTest do
  # the invite at the end of each post, and /subscribe ticking the worlds it
  # links with
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Tags

  defp post_tagged(tags) do
    {:ok, post} = ContentFixtures.post_attrs(status: :published) |> Content.create_post()
    Tags.set_post_tags(post, tags)
    post
  end

  describe "the invite at the end of a post" do
    test "links to /subscribe with the post's worlds ticked", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      post = post_tagged(["Woodland", "techworld", "treeworld"])

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

      # in the form's order, and only the tags that are worlds
      assert has_element?(
               view,
               ~s(#subscribe-invite-link[href="/subscribe?worlds=treeworld%2Ctechworld"])
             )
    end

    test "a post in no world invites to everything", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      post = post_tagged(["Woodland"])

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

      assert has_element?(view, ~s(#subscribe-invite-link[href="/subscribe?worlds=everything"]))
    end

    test "isn't shown in the editor's preview", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      post = post_tagged([])

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}?preview=true")

      refute has_element?(view, "#subscribe-invite")
    end

    test "isn't shown to visitors while the mailing list is off", %{conn: conn} do
      post = post_tagged([])

      {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

      refute has_element?(view, "#subscribe-invite")
    end
  end

  describe "/subscribe?worlds=" do
    setup :register_and_log_in_user

    defp ticked(view) do
      ["everything" | Jamie.MailingList.worlds()]
      |> Enum.filter(fn name ->
        id = if name == "everything", do: "everything", else: "world-" <> name
        has_element?(view, "#subscriber-#{id}[checked]")
      end)
    end

    test "ticks the named worlds and ignores anything else", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/subscribe?worlds=makerworld,bogus,treeworld")
      assert ticked(view) == ["treeworld", "makerworld"]
    end

    test "everything ticks everything", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/subscribe?worlds=everything")
      assert ticked(view) == ["everything"]
    end

    test "with no worlds, or a malformed list, nothing is ticked", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/subscribe")
      assert ticked(view) == []

      {:ok, view, _html} = live(conn, "/subscribe?worlds[]=treeworld")
      assert ticked(view) == []
    end
  end
end
