defmodule JamieWeb.ContentLive.PostRepliesTest do
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :published))
    %{post: post}
  end

  defp on_bluesky(post) do
    {:ok, post} =
      Content.put_post_bluesky(post, %{
        bluesky_uri: "at://did:plc:jamietest/app.bsky.feed.post/3kpost",
        bluesky_cid: "bafy",
        bluesky_posted_at: DateTime.utc_now()
      })

    post
  end

  test "a post that isn't on Bluesky has no conversation", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")
    refute has_element?(view, "#conversation")
  end

  test "replies are fetched once the page is live and nested", %{conn: conn, post: post} do
    post = on_bluesky(post)
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")

    assert has_element?(view, "#replies-loading")
    render_async(view)

    assert has_element?(view, "#conversation h2 .count", "2")
    assert has_element?(view, "#reply-did-plc-alice-3kalice .reply-text", "Lovely post!")
    # the answer to Alice sits inside her reply
    assert has_element?(
             view,
             "#reply-did-plc-alice-3kalice ol.replies #reply-did-plc-jamietest-3kreply",
             "Thanks Alice"
           )

    assert has_element?(
             view,
             ~s|#reply-on-bluesky[href="https://bsky.app/profile/did:plc:jamietest/post/3kpost"]|
           )
  end

  test "the conversation appears when the post goes out", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")
    refute has_element?(view, "#conversation")

    on_bluesky(post)
    render_async(view)

    assert has_element?(view, "#reply-did-plc-alice-3kalice")
  end
end
