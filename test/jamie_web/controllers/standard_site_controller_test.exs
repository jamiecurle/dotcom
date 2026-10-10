defmodule JamieWeb.StandardSiteControllerTest do
  # not async: the publication uri is cached node-wide
  use JamieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Jamie.Bluesky
  alias Jamie.Content
  alias Jamie.Support.ContentFixtures
  alias Jamie.Support.FakeBluesky

  setup do
    Bluesky.forget_publication()
    on_exit(&Bluesky.forget_publication/0)
  end

  describe "GET /.well-known/site.standard.publication" do
    test "answers with the publication's at:// uri", %{conn: conn} do
      uri = "at://did:plc:jamietest/site.standard.publication/3kpub"

      FakeBluesky.put_records("site.standard.publication", [
        %{"uri" => uri, "value" => %{"url" => JamieWeb.Endpoint.url()}}
      ])

      conn = get(conn, ~p"/.well-known/site.standard.publication")

      assert response(conn, 200) == uri
      assert [content_type] = get_resp_header(conn, "content-type")
      assert content_type =~ "text/plain"
    end

    test "is a 404 until something has been published", %{conn: conn} do
      assert conn |> get(~p"/.well-known/site.standard.publication") |> response(404)
    end
  end

  describe "a post's head" do
    test "links its document record once it has one", %{conn: conn} do
      {:ok, post} = Content.create_post(ContentFixtures.post_attrs(status: :published))
      {:ok, _view, html} = live(conn, ~p"/posts/#{post.slug}")
      refute html =~ ~s(rel="site.standard.document")

      uri = "at://did:plc:jamietest/site.standard.document/3kdoc"
      {:ok, _} = Content.put_post_bluesky(post, %{standard_document_uri: uri})

      html = conn |> get(~p"/posts/#{post.slug}") |> html_response(200)

      assert html
             |> LazyHTML.from_document()
             |> LazyHTML.query(~s(link[rel="site.standard.document"][href="#{uri}"]))
             |> Enum.count() == 1
    end
  end
end
