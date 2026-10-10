defmodule JamieWeb.SubscribeLinksTest do
  # not async: one test switches the mailing list on for everyone
  use JamieWeb.ConnCase, async: false

  defp switch_on(_context) do
    config = Application.get_env(:jamie, :mailing_list)
    Application.put_env(:jamie, :mailing_list, Keyword.put(config, :enabled, true))
    on_exit(fn -> Application.put_env(:jamie, :mailing_list, config) end)
  end

  defp links(html) do
    document = LazyHTML.from_document(html)

    %{
      nav: LazyHTML.query(document, "#nav-subscribe") |> Enum.count(),
      footer: LazyHTML.query(document, "#footer-subscribe") |> Enum.count()
    }
  end

  describe "with the mailing list on" do
    setup :switch_on

    test "the nav and footer link to /subscribe", %{conn: conn} do
      assert links(html_response(get(conn, ~p"/about"), 200)) == %{nav: 1, footer: 1}
    end

    test "so do LiveView pages", %{conn: conn} do
      assert links(html_response(get(conn, ~p"/subscribe"), 200)) == %{nav: 1, footer: 1}
    end
  end

  test "with it off, visitors see no links", %{conn: conn} do
    assert links(html_response(get(conn, ~p"/about"), 200)) == %{nav: 0, footer: 0}
  end

  test "with it off, I still see them signed in", %{conn: conn} do
    %{conn: conn} = register_and_log_in_user(%{conn: conn})
    assert links(html_response(get(conn, ~p"/about"), 200)) == %{nav: 1, footer: 1}
  end
end
