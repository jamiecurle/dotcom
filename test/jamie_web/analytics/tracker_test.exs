defmodule JamieWeb.Analytics.TrackerTest do
  use JamieWeb.ConnCase, async: true

  alias JamieWeb.Analytics.Tracker
  alias Phoenix.LiveView.Socket

  test "doesn't attach tracking for a signed-in visit" do
    scope = Jamie.AccountsFixtures.user_scope_fixture()
    socket = %Socket{assigns: %{__changed__: %{}, current_scope: scope}}

    assert {:cont, socket} = Tracker.on_mount(:track_pageviews, %{}, %{}, socket)
    refute Map.has_key?(socket.assigns, :analytics_visitor)
  end
end
