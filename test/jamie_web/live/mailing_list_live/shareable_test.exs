defmodule JamieWeb.MailingListLive.ShareableTest do
  # /subscribe making a good link card, and asking new subscribers to share it
  use JamieWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_log_in_user

  test "the page has its own og:image, and it exists", %{conn: conn} do
    image = JamieWeb.Endpoint.url() <> "/images/og-subscribe.png"

    html = conn |> get(~p"/subscribe") |> html_response(200)

    assert html
           |> LazyHTML.from_document()
           |> LazyHTML.query(~s(meta[property="og:image"][content="#{image}"]))
           |> Enum.any?()

    assert File.exists?(Application.app_dir(:jamie, "priv/static/images/og-subscribe.png"))
  end

  test "after signing up, a link to share it on Bluesky", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/subscribe")
    refute has_element?(view, "#share-on-bluesky")

    view
    |> element("#subscribe-form")
    |> render_submit(%{
      "subscriber" => %{
        "email" => "reader@example.com",
        "everything" => "true",
        "frequency" => "weekly",
        "consent" => "true"
      },
      "cf-turnstile-response" => "pass"
    })

    href =
      view
      |> element("#share-on-bluesky")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.attribute("href")
      |> List.first()

    assert %URI{host: "bsky.app", path: "/intent/compose", query: query} = URI.parse(href)
    assert URI.decode_query(query)["text"] =~ JamieWeb.Endpoint.url() <> "/subscribe"
  end
end
