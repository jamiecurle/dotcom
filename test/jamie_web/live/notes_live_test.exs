defmodule Jamie.Blog.NotesLiveTest do
  use JamieWeb.ConnCase, async: true

  # alias Jamie.Blog
  alias Jamie.Blog.Note
  alias Jamie.Repo
  import Phoenix.LiveViewTest
  import Jamie.AccountsFixtures
  # alias Jamie.Support.BlogFixtures

  @url "/office/notes/"

  # defp create_note(attrs) do
  #   {:ok, note} = attrs |> BlogFixtures.note_attrs() |> Blog.create_note()
  #   note
  # end

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
        }}} = live(conn, @url <> "new")
    end

    test "renders the form if a user is logged in", %{conn: conn, user: user} do
      # now we get a live view process to play with
      {:ok, view, _html} =
        conn
        |> log_in_user(user)
        |> live(@url <> "new")

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
      {:ok, view, _} = live(conn, @url <> "new")

      # there are no notes
      assert 0 == Repo.aggregate(Note, :count)

      view
      |> form("#note-form", %{note: %{markdown: "A note for you", status: "draft"}})
      |> render_submit()

      # there are still no notes
      assert 0 == Repo.aggregate(Note, :count)
    end

    test "note shows error when title is missing", %{conn: conn} do
      {:ok, view, _} = live(conn, @url <> "new")

      view
      |> form("#note-form", %{note: %{markdown: "A note for you", status: "draft"}})
      |> render_submit()

      assert 0 == Repo.aggregate(Note, :count)
      assert render(view) =~ "could not save note"
    end

    test "note saves when all is present ", %{conn: conn} do
      # get the live view
      {:ok, view, _} = live(conn, @url <> "new")

      # there are no notes
      assert 0 == Repo.aggregate(Note, :count)

      view
      |> form("#note-form", %{
        note: %{markdown: "A note for you", title: "a note", status: "draft"}
      })
      |> render_submit()

      # there is now one note and we redirected to the edit page
      note = Repo.one(Note)
      assert_redirect(view, ~p"/office/notes/#{note.id}")
    end
  end

  # describe "editing a note works as expected" do
  #   setup %{conn: conn} do
  #     user = user_fixture()
  #     note = create_note(title: "this is the note", markdown: "* list")
  #     %{user: user, conn: log_in_user(conn, user), note: note}
  #   end

  #   test "edit works as expected", %{conn: conn, note: note} do
  #     # get the live view
  #     {:ok, view, _} = live(conn, @url <> "#{note.id}")

  #     # one note and the title is what we expect
  #     note = Repo.one(Note)
  #     assert note.title == "this is the note"
  #     assert note.markdown == "* list"

  #     # submit the form
  #     view
  #     |> form("#note-form", %{
  #       note: %{markdown: "An edited note", title: "this still is the note"}
  #     })
  #     |> render_submit()

  #     #
  #     # one note and the title is what we expect
  #     note = Repo.one(Note)
  #     assert note.title == "this still is the note"
  #     assert note.markdown == "An edited note"
  #   end
  # end
end
