defmodule Jamie.Support.FakeReq do
  @moduledoc """
  A fake version of the req library for testing.
  """

  @doc """
  Fake respsonses for testing the collecting bookmarks
  """
  def request(params, opts \\ [])

  def request([url: "https://your.linkding/api/bookmarks/"] ++ _, _opts) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => "https://your.linkding/api/bookmarks/?limit=2&offset=2",
         "previous" => nil,
         "results" => [
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
       }
     }}
  end

  def request([url: "https://your.linkding/api/bookmarks/?limit=2&offset=2"] ++ _, _opts) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => nil,
         "previous" => "https://your.linkding/api/bookmarks/?limit=2",
         "results" => [
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
             "web_archive_snapshot_url" =>
               "https://web.archive.org/web/20260707162938/https://labs.uk.barclays/demo-directory/founders/demo-day-founder-registration/",
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
       }
     }}
  end
end
