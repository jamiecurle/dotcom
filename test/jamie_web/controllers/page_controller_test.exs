defmodule JamieWeb.PageControllerTest do
  use JamieWeb.ConnCase

  alias Jamie.Analytics
  alias Jamie.Support.ContentFixtures

  test "GET /", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200)
  end

  describe "GET / with plenty of writing" do
    setup do
      posts =
        for n <- 1..12 do
          {:ok, post} =
            ContentFixtures.post_attrs(title: "Post #{n}", status: :published)
            |> Jamie.Content.create_post()

          # publishing stamps today's date; spread them out so the order is known
          post
          |> Ecto.Changeset.change(published_on: Date.add(~D[2026-01-01], n))
          |> Jamie.Repo.update!()
        end

      # newest first, as the homepage lists them
      %{posts: Enum.reverse(posts)}
    end

    test "the first ten sit in the photo and the rest in the band underneath",
         %{conn: conn, posts: posts} do
      doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
      {in_photo, in_band} = Enum.split(posts, 10)

      for post <- in_photo do
        refute Enum.empty?(LazyHTML.query(doc, "#alreet #post-#{post.id}"))
      end

      for post <- in_band do
        refute Enum.empty?(LazyHTML.query(doc, "#earlier-writing #post-#{post.id}"))
      end

      assert LazyHTML.query(doc, "#all-writing") |> Enum.count() == 1
    end

    test "most read ranks posts by readers once five have been read",
         %{conn: conn, posts: posts} do
      # the fifth post gets the most readers, the others one each
      for {post, n} <- Enum.zip(Enum.take(posts, 5), [1, 1, 1, 1, 3]),
          reader <- 1..n do
        Analytics.track(%{path: "/posts/#{post.slug}", visitor_hash: "reader-#{reader}"})
      end

      doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
      ranked = doc |> LazyHTML.query("#most-read ol.ranked a") |> LazyHTML.attribute("id")

      assert length(ranked) == 5
      assert hd(ranked) == "popular-#{Enum.at(posts, 4).id}"
    end

    test "most read stays hidden with fewer than five posts read",
         %{conn: conn, posts: posts} do
      for post <- Enum.take(posts, 4) do
        Analytics.track(%{path: "/posts/#{post.slug}", visitor_hash: "reader"})
      end

      doc = conn |> get(~p"/") |> html_response(200) |> LazyHTML.from_document()
      assert Enum.empty?(LazyHTML.query(doc, "#most-read"))
    end
  end

  test "GET /about", %{conn: conn} do
    conn = get(conn, ~p"/about")
    assert html_response(conn, 200) =~ "About"
  end

  for path <- ["/about", "/privacy"] do
    test "GET #{path} is laid out like a post, with contents that link to its sections",
         %{conn: conn} do
      doc = conn |> get(unquote(path)) |> html_response(200) |> LazyHTML.from_document()

      refute Enum.empty?(LazyHTML.query(doc, "header.masthead h1.page-title"))
      refute Enum.empty?(LazyHTML.query(doc, ".post-body h2"))

      anchors =
        doc |> LazyHTML.query("aside.margin-nav ol.numbered a") |> LazyHTML.attribute("href")

      refute anchors == []

      for "#" <> id <- anchors do
        refute Enum.empty?(LazyHTML.query(doc, ~s(.post-body [id="#{id}"]))),
               "no section for ##{id}"
      end
    end
  end

  test "GET /privacy", %{conn: conn} do
    conn = get(conn, ~p"/privacy")
    assert html_response(conn, 200) =~ "Privacy"
  end

  test "GET /projects", %{conn: conn} do
    conn = get(conn, ~p"/projects")
    assert html_response(conn, 200) =~ "Projects"
  end

  describe ~s(<link rel="alternate" type="text/markdown">) do
    test "is present on pages with a markdown rendering", %{conn: conn} do
      for path <- [~p"/", ~p"/about", ~p"/privacy", ~p"/projects"] do
        body = conn |> get(path) |> html_response(200)
        assert body =~ ~s(rel="alternate")
        assert body =~ ~s(type="text/markdown")
        assert body =~ ~s(href="#{path}")
        assert body =~ ~s(title="LLM-readable version")
      end
    end

    test "is absent on pages without a markdown rendering", %{conn: conn} do
      body = conn |> get(~p"/front-door/log-in") |> html_response(200)
      refute body =~ ~s(type="text/markdown")
    end
  end
end
