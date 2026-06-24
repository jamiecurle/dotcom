defmodule Jamie.Workers.OgImageCreateTest do
  use Jamie.DataCase
  use Oban.Testing, repo: Jamie.Repo

  import ExUnit.CaptureLog

  alias Jamie.Workers.OgImageCreate

  describe "perform/1" do
    test "an unknown thing fails with a descriptive error" do
      # The worker logs the failure at :error, so capture it to keep test
      # output clean while still asserting on the return value.
      capture_log(fn ->
        assert {:error, :unknown_thing} =
                 perform_job(OgImageCreate, %{"thing" => "widget", "id" => 1})
      end)
    end
  end
end
