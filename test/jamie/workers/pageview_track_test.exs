defmodule Jamie.Workers.PageviewTrackTest do
  use Jamie.DataCase, async: true
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Analytics
  alias Jamie.Workers.PageviewTrack

  test "persists a valid pageview" do
    assert :ok =
             perform_job(PageviewTrack, %{
               "path" => "/",
               "device_type" => "desktop",
               "visitor_hash" => "abc"
             })

    assert Analytics.total_pageviews(1) == 1
  end

  test "cancels (does not retry) an invalid pageview" do
    assert {:cancel, :invalid_pageview} = perform_job(PageviewTrack, %{"path" => "/"})
  end
end
