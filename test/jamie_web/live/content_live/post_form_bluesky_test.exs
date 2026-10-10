defmodule JamieWeb.ContentLive.PostFormBlueskyTest do
  # not async: one test switches the Bluesky config off
  use JamieWeb.ConnCase, async: false
  use Oban.Testing, repo: Jamie.Repo

  import Phoenix.LiveViewTest

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Workers.BlueskyPublish

  setup :register_and_log_in_user

  setup do
    {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :published))
    %{post: post}
  end

  test "drafts don't offer it", %{conn: conn} do
    {:ok, draft} = Content.create_post(ContentFixtures.post_attrs(title: "A draft"))
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{draft.id}")

    refute has_element?(view, "#bluesky")
  end

  test "composing starts from the title and description", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    refute has_element?(view, "#bluesky-form")
    view |> element("#bluesky-compose") |> render_click()

    assert has_element?(view, "#bluesky-form textarea", post.title)
    assert has_element?(view, "#bluesky-card", post.title)
    assert has_element?(view, "#bluesky-count", "#{String.length(post.title) + 2 + 20} / 300")
  end

  test "too many characters can't be published", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    view |> element("#bluesky-compose") |> render_click()

    view
    |> form("#bluesky-form", bluesky: %{text: String.duplicate("a", 301)})
    |> render_change()

    assert has_element?(view, "#bluesky-count.text-error", "301 / 300")
    assert has_element?(view, "#bluesky-publish[disabled]")
  end

  test "publishing queues the job and shows it's on its way", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    view |> element("#bluesky-compose") |> render_click()

    view |> form("#bluesky-form", bluesky: %{text: "Read this"}) |> render_submit()

    assert_enqueued(
      worker: BlueskyPublish,
      args: %{"action" => "publish", "post_id" => post.id, "text" => "Read this"}
    )

    assert has_element?(view, "#bluesky-pending", "Publishing")
    refute has_element?(view, "#bluesky-form")
  end

  test "the worker's news shows up", %{conn: conn, post: post} do
    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    Content.broadcast_bluesky_error(post, "Bluesky said Nope.")
    assert has_element?(view, "#bluesky-error", "Bluesky said Nope.")

    {:ok, _} =
      Content.put_post_bluesky(post, %{
        bluesky_uri: "at://did:plc:jamietest/app.bsky.feed.post/3kabc",
        bluesky_cid: "bafy",
        bluesky_posted_at: DateTime.utc_now()
      })

    assert has_element?(view, "#bluesky-published")
    assert has_element?(view, "#bluesky-document-missing")

    assert has_element?(
             view,
             ~s|#bluesky-link[href="https://bsky.app/profile/did:plc:jamietest/post/3kabc"]|
           )
  end

  test "a published post can be removed", %{conn: conn, post: post} do
    {:ok, post} =
      Content.put_post_bluesky(post, %{
        bluesky_uri: "at://did:plc:jamietest/app.bsky.feed.post/3kabc",
        bluesky_cid: "bafy",
        bluesky_posted_at: DateTime.utc_now(),
        standard_document_uri: "at://did:plc:jamietest/site.standard.document/3kdoc"
      })

    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
    refute has_element?(view, "#bluesky-compose")

    view |> element("#bluesky-remove") |> render_click()

    assert_enqueued(worker: BlueskyPublish, args: %{"action" => "remove", "post_id" => post.id})
    assert has_element?(view, "#bluesky-pending", "Removing")
  end

  describe "moderating replies" do
    setup %{post: post} do
      {:ok, post} =
        Content.put_post_bluesky(post, %{
          bluesky_uri: "at://did:plc:jamietest/app.bsky.feed.post/3kabc",
          bluesky_cid: "bafy",
          bluesky_posted_at: DateTime.utc_now(),
          standard_document_uri: "at://did:plc:jamietest/site.standard.document/3kdoc"
        })

      %{post: post}
    end

    test "lists every reply and why any are hidden", %{conn: conn, post: post} do
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
      render_async(view)

      assert has_element?(view, "#bluesky-reply-did-plc-alice-3kalice", "Lovely post!")
      assert has_element?(view, "#bluesky-reply-did-plc-jamietest-3kreply", "Thanks Alice")
      assert has_element?(view, "#bluesky-reply-did-plc-carol-3kcarol", "Hidden on Bluesky")
      assert has_element?(view, "#bluesky-reply-did-plc-spam-3kspam", "Labelled by Bluesky")
      # only my own choices can be undone here
      refute has_element?(view, "#bluesky-toggle-did-plc-carol-3kcarol")
      refute has_element?(view, "#bluesky-toggle-did-plc-spam-3kspam")
    end

    test "hiding and showing a reply on the blog", %{conn: conn, post: post} do
      alice = "at://did:plc:alice/app.bsky.feed.post/3kalice"
      {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")
      render_async(view)

      view |> element("#bluesky-toggle-did-plc-alice-3kalice") |> render_click()

      assert Content.get_post!(post.id).bluesky_hidden_replies == [alice]
      assert has_element?(view, "#bluesky-reply-did-plc-alice-3kalice", "Hidden on blog")
      assert has_element?(view, "#bluesky-toggle-did-plc-alice-3kalice", "Show on blog")

      view |> element("#bluesky-toggle-did-plc-alice-3kalice") |> render_click()

      assert Content.get_post!(post.id).bluesky_hidden_replies == []
      assert has_element?(view, "#bluesky-toggle-did-plc-alice-3kalice", "Hide on blog")
    end
  end

  test "says so when it isn't set up", %{conn: conn, post: post} do
    config = Application.get_env(:jamie, :bluesky)
    Application.put_env(:jamie, :bluesky, Keyword.put(config, :app_password, nil))
    on_exit(fn -> Application.put_env(:jamie, :bluesky, config) end)

    {:ok, view, _html} = live(conn, ~p"/office/posts/#{post.id}")

    assert has_element?(view, "#bluesky-not-configured")
    refute has_element?(view, "#bluesky-compose")
  end
end
