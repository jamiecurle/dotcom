defmodule JamieWeb.FeedHomeSubscribeTest do
  # the feed and the homepage pointing at /subscribe. Not async: some tests
  # switch the mailing list on for everyone.
  use JamieWeb.ConnCase, async: false

  alias Jamie.Content
  alias Jamie.Support.ContentFixtures

  defp switch_on(_context) do
    config = Application.get_env(:jamie, :mailing_list)
    Application.put_env(:jamie, :mailing_list, Keyword.put(config, :enabled, true))
    on_exit(fn -> Application.put_env(:jamie, :mailing_list, config) end)
  end

  defp published_post(_context) do
    {:ok, post} = ContentFixtures.post_attrs(status: :published) |> Content.create_post()
    %{post: post}
  end

  defp home_link?(conn) do
    conn
    |> get(~p"/")
    |> html_response(200)
    |> LazyHTML.from_document()
    |> LazyHTML.query("#home-subscribe[href='/subscribe']")
    |> Enum.any?()
  end

  describe "with the mailing list on" do
    setup [:switch_on, :published_post]

    test "the feed's subtitle and each entry point at /subscribe", %{conn: conn} do
      body = conn |> get(~p"/feed.xml") |> response(200)

      assert body =~ ~r{<subtitle>[^<]*/subscribe</subtitle>}
      # the entry's html is escaped inside <content>
      assert body =~ "&lt;a href=&quot;#{JamieWeb.Endpoint.url()}/subscribe&quot;&gt;"
    end

    test "the homepage links to /subscribe", %{conn: conn} do
      assert home_link?(conn)
    end
  end

  describe "with it off" do
    setup :published_post

    test "the feed doesn't mention it, even to me", %{conn: conn} do
      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      body = conn |> get(~p"/feed.xml") |> response(200)

      refute body =~ "<subtitle>"
      refute body =~ "/subscribe"
    end

    test "the homepage only links to it for me", %{conn: conn} do
      refute home_link?(conn)

      %{conn: conn} = register_and_log_in_user(%{conn: conn})
      assert home_link?(conn)
    end
  end
end
