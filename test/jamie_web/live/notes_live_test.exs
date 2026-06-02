defmodule Jamie.Blog.NotesLiveTest do
  use JamieWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  import Jamie.AccountsFixtures

  @url "/office/notes/new"

  describe "auth required tests" do
    setup do
      %{user: user_fixture()}
    end

    test "form redirects if with a standard view", %{conn: conn} do
      # first the connection is a standard request.
      assert 302 == (conn |> get("/office/notes/new")).status
    end

    test "form redirects if not logged in with live view", %{conn: conn} do
      # live "upgrades the connection" so we have a live view process to interact
      # with, but not here.
      {:error,
       {:redirect,
        %{
          to: "/users/log-in"
        }}} = live(conn, @url)
    end

    test "renders the form if a user is logged in", %{conn: conn, user: user} do
      # now we get a live view process to play with
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(@url)

      # so now we can do some liveview things
      # has a form element that can submit
      form = element(view, ~s(form#note-form))
      assert has_element?(form)
    end
  end

  describe "given the correct data the form will save and create a note" do
    setup %{conn: conn} do
      user = user_fixture()
      %{user: user, conn: log_in_user(conn, user)}
    end

    test "invalid with only a title", %{conn: conn} do
      # get the live view
      {:ok, view, _} = live(conn, @url)

      # html =
      view
      |> form("#note-form", %{note: %{title: "A note for you"}})
      |> render_change()

      # assert html =~ "markdown is required"
    end
  end
end
