defmodule Jamie.Blog.NotesLiveTest do
  use JamieWeb.ConnCase, async: true

  alias Jamie.Blog.Note
  alias Jamie.Repo
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

    test "invalid without a title", %{conn: conn} do
      # get the live view
      {:ok, view, _} = live(conn, @url)

      # there are no notes
      assert 0 == Repo.aggregate(Note, :count)

      view
      |> element("#note-form")
      |> render_submit(%{note: %{markdown: "A note for you", status: "draft"}})

      # there are still no notes
      assert 0 == Repo.aggregate(Note, :count)
    end

    test "note shows error when title is missing", %{conn: conn} do
      {:ok, view, _} = live(conn, @url)

      view
      |> element("#note-form")
      |> render_submit(%{
        note: %{markdown: "A note for you", title: "", status: "draft"}
      })

      assert 0 == Repo.aggregate(Note, :count)
      assert render(view) =~ "could not save note"
    end

    test "note saves when all is present ", %{conn: conn} do
      # get the live view
      {:ok, view, _} = live(conn, @url)

      # there are no notes
      assert 0 == Repo.aggregate(Note, :count)

      view
      |> element("#note-form")
      |> render_submit(%{
        note: %{markdown: "A note for you", title: "the title", status: "draft"}
      })

      # there is now one note and we redirected to the edit page
      note = Repo.one(Note)
      assert_redirect(view, ~p"/office/notes/#{note.id}")
    end
  end
end
