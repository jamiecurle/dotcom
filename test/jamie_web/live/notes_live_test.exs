defmodule Jamie.Blog.NotesLiveTest do
  use JamieWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Jamie.AccountsFixtures

  setup do
    %{user: user_fixture()}
  end

  describe "auth tests" do
    test "form redirects it not logged in", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          to: "/users/log-in"
        }}} = live(conn, "/office/notes/new")
    end

    test "renders the form if a user is logged in", %{conn: conn, user: user} do
      {:ok, _view, _html} =
        conn
        |> log_in_user(user)
        |> live("/office/notes/new")
    end
  end
end
