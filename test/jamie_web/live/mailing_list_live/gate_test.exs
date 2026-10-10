defmodule JamieWeb.MailingListLive.GateTest do
  # not async: one test switches the mailing list on for everyone
  use JamieWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  describe "while the mailing list is off" do
    test "it doesn't exist for visitors", %{conn: conn} do
      assert_error_sent 404, fn -> get(conn, ~p"/subscribe") end
    end

    test "I can see it when signed in", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      {:ok, view, _html} = live(conn, ~p"/subscribe")

      assert has_element?(view, "#world-treeworld")
    end
  end

  test "switched on, everyone can see it", %{conn: conn} do
    config = Application.get_env(:jamie, :mailing_list)
    Application.put_env(:jamie, :mailing_list, enabled: true)
    on_exit(fn -> Application.put_env(:jamie, :mailing_list, config) end)

    {:ok, view, _html} = live(conn, ~p"/subscribe")
    assert has_element?(view, "#worlds")
  end

  test "visible?/1 is me always, everyone else only when it's on" do
    alias Jamie.Accounts.Scope
    alias Jamie.MailingList

    refute MailingList.visible?(nil)
    refute MailingList.visible?(%Scope{user: nil})
    assert MailingList.visible?(%Scope{user: %Jamie.Accounts.User{}})
  end
end
