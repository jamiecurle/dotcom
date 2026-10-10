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

    # the static render only promises them; checking that on the live view
    # races the fetch, which can land before the assertion
    html = conn |> get(~p"/posts/#{post.slug}") |> html_response(200)
    assert html |> LazyHTML.from_document() |> LazyHTML.query("#replies-loading") |> Enum.any?()

    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")
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

  test "replies hidden on Bluesky, labelled, or hidden on the blog stay off the page", %{
    conn: conn,
    post: post
  } do
    post = on_bluesky(post)
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")
    render_async(view)

    refute has_element?(view, "#reply-did-plc-carol-3kcarol")
    refute has_element?(view, "#reply-did-plc-spam-3kspam")
    assert has_element?(view, "#reply-did-plc-alice-3kalice")

    # hiding Alice on the blog takes her and the answer to her off the page
    {:ok, _} = Content.toggle_bluesky_reply(post, "at://did:plc:alice/app.bsky.feed.post/3kalice")
    render_async(view)

    refute has_element?(view, "#reply-did-plc-alice-3kalice")
    assert has_element?(view, "#replies-empty")
  end

  test "the conversation appears when the post goes out", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/posts/#{post.slug}")
    refute has_element?(view, "#conversation")

    on_bluesky(post)
    render_async(view)

    assert has_element?(view, "#reply-did-plc-alice-3kalice")
  end
end
