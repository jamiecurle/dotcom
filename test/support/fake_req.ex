defmodule Jamie.Support.FakeReq do
  @moduledoc """
  A fake version of the req library for testing.
  """
  def request("https://your.linkding/api/bookmarks/", _opts \\ []) do
    {:ok,
     %{
       body: %{
         "count" => 3,
         "next" => "https://your.linkding/api/bookmarks/?limit=2&offset=2",
         "previous" => "https://your.linkding/api/bookmarks/?limit=2",
         "results" => [
           %{
             "date_added" => "2026-07-07T06:12:57.343997Z",
             "date_modified" => "2026-07-07T06:13:02.222308Z",
             "description" =>
               "I have now sequenced my own genome 5 times with an Oxford Nanopore Technologies MinION. This means collecting them from a swab, prepping them for sequencing, running them through a sequencer, then doing analysis over them.",
             "favicon_url" => "https://your.linkding/static/https_bradleywoolf_com.png",
             "id" => 360,
             "is_archived" => false,
             "notes" => "",
             "preview_image_url" =>
               "https://your.linkding/static/0a2cdbe846891577d6977a326787d178.jpg",
             "shared" => false,
             "tag_names" => ["dna", "health", "techworld"],
             "title" => "How to sequence your own DNA at home",
             "unread" => false,
             "url" => "https://bradleywoolf.com/links-1/sequencing-my-own-dna-at-home",
             "web_archive_snapshot_url" =>
               "https://web.archive.org/web/20260707061257/https://bradleywoolf.com/links-1/sequencing-my-own-dna-at-home",
             "website_description" => nil,
             "website_title" => nil
           },
           %{
             "date_added" => "2026-07-06T07:34:48.266162Z",
             "date_modified" => "2026-07-06T07:34:54.119337Z",
             "description" =>
               "This comprehensive course covers the full spectrum of working with Anthropic models using the Claude API",
             "favicon_url" => "https://your.linkding/static/https_anthropic_skilljar_com.png",
             "id" => 359,
             "is_archived" => false,
             "notes" => "",
             "preview_image_url" =>
               "https://your.linkding/static/048bd59d605760ab72b286e37f4feb89.svg",
             "shared" => false,
             "tag_names" => ["anthropic", "learn", "techworld"],
             "title" => "Building with the Claude API",
             "unread" => true,
             "url" => "https://anthropic.skilljar.com/claude-with-the-anthropic-api",
             "web_archive_snapshot_url" =>
               "https://web.archive.org/web/20260706073448/https://anthropic.skilljar.com/claude-with-the-anthropic-api",
             "website_description" => nil,
             "website_title" => nil
           }
         ]
       }
     }}
  end
end
