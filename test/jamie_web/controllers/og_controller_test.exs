defmodule JamieWeb.OgControllerTest do
  use JamieWeb.ConnCase

  describe "GET /opengraph/:thing/:id" do
    setup do
      %{"post" => "post"}
    end

    test "404 if thing isn't supported", %{conn: conn} do
      conn = get(conn, ~p"/opengraph/blog/1")
      assert conn.status == 404
    end

    test "200 if it is supported", %{conn: conn} do
      conn = get(conn, ~p"/opengraph/post/1")
      assert text_response(conn, 200) == "hello world"
    end
  end
end
