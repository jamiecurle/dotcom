defmodule Jamie.Workers.OgImageCreateTest do
  use Jamie.DataCase
  use Oban.Testing, repo: Jamie.Repo

  alias Jamie.Workers.OgImageCreate

  describe "perform/1" do
    test "an unknown thing fails with a descriptive error" do
      assert {:error, :unknown_thing} =
               perform_job(OgImageCreate, %{"thing" => "widget", "id" => 1})
    end
  end
end
