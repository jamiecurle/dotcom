defmodule JamieWeb.Plugs.TrackPageviewTest do
  use JamieWeb.ConnCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Workers.PageviewTrack
  alias JamieWeb.Plugs.TrackPageview

  @chrome "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
  @googlebot "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  defp run(conn) do
    conn
    |> TrackPageview.call(TrackPageview.init([]))
    |> put_resp_content_type("text/html")
    |> send_resp(200, "<html></html>")
  end

  test "enqueues a pageview for a successful HTML GET" do
    build_conn(:get, "/about")
    |> put_req_header("user-agent", @chrome)
    |> run()

    assert_enqueued(worker: PageviewTrack, args: %{path: "/about", device_type: "desktop"})
  end

  test "records the country stashed by the VisitorCountry plug" do
    # In the real pipeline the VisitorCountry plug runs upstream and puts the
    # normalized code in conn.assigns; here we set it directly.
    build_conn(:get, "/about")
    |> put_req_header("user-agent", @chrome)
    |> assign(:visitor_country, "GB")
    |> run()

    assert_enqueued(worker: PageviewTrack, args: %{path: "/about", country: "GB"})
  end

  test "records a nil country when none was captured" do
    build_conn(:get, "/about")
    |> put_req_header("user-agent", @chrome)
    |> run()

    assert_enqueued(worker: PageviewTrack, args: %{path: "/about", country: nil})
  end

  test "doesn't capture the homepage for a standard visitor" do
    build_conn(:get, "/")
    |> put_req_header("user-agent", @chrome)
    |> run()

    refute_enqueued(worker: PageviewTrack, args: %{path: "/", country: nil})
  end

  test "does not enqueue for crawlers" do
    build_conn(:get, "/")
    |> put_req_header("user-agent", @googlebot)
    |> run()

    refute_enqueued(worker: PageviewTrack)
  end

  test "does not enqueue for non-GET requests" do
    build_conn(:post, "/")
    |> put_req_header("user-agent", @chrome)
    |> run()

    refute_enqueued(worker: PageviewTrack)
  end

  test "does not enqueue for skipped prefixes" do
    build_conn(:get, "/office/analytics")
    |> put_req_header("user-agent", @chrome)
    |> run()

    refute_enqueued(worker: PageviewTrack)
  end

  test "does not enqueue for non-HTML responses" do
    build_conn(:get, "/feed.xml")
    |> put_req_header("user-agent", @chrome)
    |> TrackPageview.call(TrackPageview.init([]))
    |> put_resp_content_type("application/xml")
    |> send_resp(200, "<feed/>")

    refute_enqueued(worker: PageviewTrack)
  end

  test "does not enqueue for error responses" do
    build_conn(:get, "/")
    |> put_req_header("user-agent", @chrome)
    |> TrackPageview.call(TrackPageview.init([]))
    |> put_resp_content_type("text/html")
    |> send_resp(404, "not found")

    refute_enqueued(worker: PageviewTrack)
  end
end
