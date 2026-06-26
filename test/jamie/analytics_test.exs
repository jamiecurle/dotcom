defmodule Jamie.AnalyticsTest do
  use Jamie.DataCase, async: true

  alias Jamie.Analytics
  alias Jamie.Analytics.Pageview
  alias Jamie.Repo

  @chrome "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36"
  @iphone "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  @ipad "Mozilla/5.0 (iPad; CPU OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"
  @googlebot "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)"

  describe "visitor_hash/3" do
    test "is stable for the same visitor within a day" do
      assert Analytics.visitor_hash("1.2.3.4", "ua", ~D[2026-06-26]) ==
               Analytics.visitor_hash("1.2.3.4", "ua", ~D[2026-06-26])
    end

    test "rotates across days so visitors can't be tracked over time" do
      refute Analytics.visitor_hash("1.2.3.4", "ua", ~D[2026-06-26]) ==
               Analytics.visitor_hash("1.2.3.4", "ua", ~D[2026-06-27])
    end

    test "differs for different IPs" do
      refute Analytics.visitor_hash("1.2.3.4", "ua", ~D[2026-06-26]) ==
               Analytics.visitor_hash("5.6.7.8", "ua", ~D[2026-06-26])
    end

    test "does not contain the raw IP" do
      hash = Analytics.visitor_hash("198.51.100.7", "ua", ~D[2026-06-26])
      refute hash =~ "198.51.100.7"
    end
  end

  describe "parse_user_agent/1" do
    test "classifies a desktop browser" do
      assert %{browser: "Chrome", os: "Mac OS X", device_type: "desktop"} =
               Analytics.parse_user_agent(@chrome)
    end

    test "classifies a phone as mobile" do
      assert %{device_type: "mobile", os: "iOS"} = Analytics.parse_user_agent(@iphone)
    end

    test "classifies an iPad as tablet" do
      assert %{device_type: "tablet"} = Analytics.parse_user_agent(@ipad)
    end

    test "classifies a crawler as bot" do
      assert %{device_type: "bot"} = Analytics.parse_user_agent(@googlebot)
    end

    test "handles a missing user-agent" do
      assert %{browser: nil, os: nil, device_type: "other"} = Analytics.parse_user_agent(nil)
    end
  end

  describe "referrer_host/2" do
    test "extracts the host of an external referrer" do
      assert Analytics.referrer_host("https://news.ycombinator.com/item?id=1", "jamiecurle.com") ==
               "news.ycombinator.com"
    end

    test "drops self-referrals" do
      assert Analytics.referrer_host("https://jamiecurle.com/posts", "jamiecurle.com") == nil
    end

    test "drops blank and malformed referrers" do
      assert Analytics.referrer_host(nil, "jamiecurle.com") == nil
      assert Analytics.referrer_host("", "jamiecurle.com") == nil
      assert Analytics.referrer_host("not a url", "jamiecurle.com") == nil
    end
  end

  describe "track/1 and aggregates" do
    setup do
      for attrs <- [
            %{path: "/", device_type: "desktop", browser: "Chrome", visitor_hash: "a"},
            %{path: "/", device_type: "mobile", browser: "Safari", visitor_hash: "b"},
            %{path: "/about", device_type: "desktop", browser: "Chrome", visitor_hash: "a"},
            %{
              path: "/posts",
              referrer_host: "news.ycombinator.com",
              device_type: "desktop",
              browser: "Firefox",
              visitor_hash: "c"
            }
          ] do
        {:ok, _} = Analytics.track(attrs)
      end

      :ok
    end

    test "counts total pageviews" do
      assert Analytics.total_pageviews(7) == 4
    end

    test "counts distinct visitors" do
      assert Analytics.unique_visitors(7) == 3
    end

    test "top_pages ranks paths by views" do
      assert [%{label: "/", count: 2} | _] = Analytics.top_pages(7)
    end

    test "top_referrers only lists external hosts" do
      assert [%{label: "news.ycombinator.com", count: 1}] = Analytics.top_referrers(7)
    end

    test "breakdown_by groups a dimension" do
      assert [%{label: "desktop", count: 3} | _] = Analytics.breakdown_by(:device_type, 7)
    end

    test "requires path and visitor_hash" do
      assert {:error, changeset} = Analytics.track(%{path: "/"})
      assert %{visitor_hash: ["can't be blank"]} = errors_on(changeset)
    end
  end

  describe "total_sessions/1" do
    # inserted_at is set by the DB on a normal insert, so build rows directly
    # to control timing.
    defp pageview_at(visitor_hash, minutes_ago) do
      at = DateTime.add(DateTime.utc_now(), -minutes_ago * 60, :second)
      Repo.insert!(%Pageview{visitor_hash: visitor_hash, path: "/", inserted_at: at})
    end

    test "groups a visitor's nearby pageviews into one visit" do
      pageview_at("a", 0)
      pageview_at("a", 5)
      pageview_at("a", 20)

      assert Analytics.total_sessions(1) == 1
    end

    test "a gap longer than the 60-minute timeout starts a new visit" do
      pageview_at("a", 0)
      pageview_at("a", 90)

      assert Analytics.total_sessions(1) == 2
    end

    test "different visitors are separate visits" do
      pageview_at("a", 0)
      pageview_at("b", 0)

      assert Analytics.total_sessions(1) == 2
    end

    test "a refresh does not add a visit" do
      pageview_at("a", 0)
      pageview_at("a", 0)

      assert Analytics.total_sessions(1) == 1
      assert Analytics.total_pageviews(1) == 2
    end
  end
end
