defmodule Jamie.Support.FakeReq do
  @moduledoc """
  A fake version of the req library for testing where each function matches Req

  The pattern for reusability is to set the base url to something unique to each test.

  Whilst Req does have it's own methods for testing, they are specific to Req. This pattern,
  however, allows all my code to use the same testing approach when dealing with external
  systems.

  Where url are used in matching, the domain will point to the test file. dot describe points
  to a describe block, dot test to a specific test etc.  This is how the pattern is extensible.
  Sometimes I'll abbreviate, but the point is that the url points to the testfile

  It is fragile with Req though as url is often a Keyword argument and so it has to come first
  when pattern matching.
  """

  @doc """
  Fake respsonses Req.request/2
  """
  def request(params, opts \\ [])

  # sync_bookmark_test - favicon and preview images - simulate a 1x1 RGBA png
  def request([url: "https://foo.io/favicon.png"] ++ _, _opts) do
    {:ok,
     %{
       headers: %{"content-type" => ["image/png"]},
       body: png()
     }}
  end

  def request([url: "https://foo.io/preview.png"] ++ _, _opts) do
    {:ok,
     %{
       headers: %{"content-type" => ["image/png"]},
       body: png()
     }}
  end

  # linkding tests - page 1
  def request(
        [url: "https://linkding.test.bookmarks.describe/api/bookmarks/"] ++ _,
        _opts
      ) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => "https://linkding.test.bookmarks.describe/api/bookmarks/?limit=2&offset=2",
         "previous" => nil,
         "results" => page_one_results()
       }
     }}
  end

  # linkding tests - page 2
  def request(
        [url: "https://linkding.test.bookmarks.describe/api/bookmarks/?limit=2&offset=2"] ++ _,
        _opts
      ) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => nil,
         "previous" => "https://linkding.test.bookmarks.describe/api/bookmarks/?limit=2",
         "results" => page_two_results()
       }
     }}
  end

  # sync bookmarks - page 1
  def request(
        [url: "https://syncbookmarks.test.worker.describe/api/bookmarks/"] ++ _,
        _opts
      ) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => "https://syncbookmarks.test.worker.describe/api/bookmarks/?limit=2&offset=2",
         "previous" => nil,
         "results" => page_one_results()
       }
     }}
  end

  # sync bookmarks - page 2
  def request(
        [url: "https://syncbookmarks.test.worker.describe/api/bookmarks/?limit=2&offset=2"] ++ _,
        _opts
      ) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => nil,
         "previous" => "https://linkding.test.bookmarks.describe/api/bookmarks/?limit=2",
         "results" => page_two_results()
       }
     }}
  end

  # default page 2
  def request(
        [url: "https://your.linkding/api/bookmarks/?limit=2&offset=2"] ++ _,
        _opts
      ) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => nil,
         "previous" => "https://your.linkding/api/bookmarks/?limit=2",
         "results" => page_two_results()
       }
     }}
  end

  # default catch all
  def request(_, _opts) do
    {:ok,
     %{
       headers: %{"content-type" => ["application/json"]},
       body: %{
         "count" => 3,
         "next" => "https://your.linkding/api/bookmarks/?limit=2&offset=2",
         "previous" => nil,
         "results" => page_one_results()
       }
     }}
  end

  # a fake png
  defp png do
    <<137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6,
      0, 0, 0, 31, 21, 196, 137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1,
      13, 10, 45, 184, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130>>
  end

  # page one and page two: saves spewing out the same data over and over again
  defp page_one_results do
    [
      %{
        "date_added" => "2026-07-07T06:12:57.343997Z",
        "date_modified" => "2026-07-07T06:13:02.222308Z",
        "description" => "I have now sequenced my own genome",
        "favicon_url" => "https://your.linkding/static/https_bradleywoolf_com.png",
        "id" => 360,
        "is_archived" => false,
        "notes" => "",
        "preview_image_url" => "https://your.linkding/static/0a78.jpg",
        "shared" => false,
        "tag_names" => ["dna", "health", "techworld"],
        "title" => "How to sequence your own DNA at home",
        "unread" => false,
        "url" => "https://bradleywoolf.com/links-1/sequencing-my-own-dna-at-home",
        "web_archive_snapshot_url" => "https://web.archive.org/encing-my-own-dna-at-home",
        "website_description" => nil,
        "website_title" => nil
      },
      %{
        "date_added" => "2026-07-06T07:34:48.266162Z",
        "date_modified" => "2026-07-06T07:34:54.119337Z",
        "description" => "This comprehensive course covers the full ",
        "favicon_url" => "https://your.linkdc_skilljar_com.png",
        "id" => 359,
        "is_archived" => false,
        "notes" => "",
        "preview_image_url" => "https://your.linkding/static/048b.svg",
        "shared" => false,
        "tag_names" => ["anthropic", "learn", "techworld"],
        "title" => "Building with the Claude API",
        "unread" => true,
        "url" => "https://anthropic.skilljar.com/claude-with-the-anthropic-api",
        "web_archive_snapshot_url" => "https://w-the-anthropic-api",
        "website_description" => nil,
        "website_title" => nil
      }
    ]
  end

  defp page_two_results do
    [
      %{
        "date_added" => "2026-07-07T16:29:38.501123Z",
        "date_modified" => "2026-07-07T16:29:43.795567Z",
        "description" => "Pitch and ask for cash",
        "favicon_url" => "https://your.linkding/static/https_labs_uk_barclays.png",
        "id" => 361,
        "is_archived" => false,
        "notes" => "",
        "preview_image_url" => nil,
        "shared" => false,
        "tag_names" => ["invest", "techworld"],
        "title" => "Demo Day Founder Registration",
        "unread" => true,
        "url" =>
          "https://labs.uk.barclays/demo-directory/founders/demo-day-founder-registration/",
        "web_archive_snapshot_url" => "https://weders/demo-day-founder-registration/",
        "website_description" => nil,
        "website_title" => nil
      }
    ]
  end
end
