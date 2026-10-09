defmodule JamieWeb.Plugs.TailnetOnlyTest do
  # not async: one test changes the :mcp_host app env
  use JamieWeb.ConnCase, async: false

  alias JamieWeb.Plugs.TailnetOnly

  test "passes the configured host through", %{conn: conn} do
    conn = conn |> Map.put(:host, "stekpi.test") |> TailnetOnly.call([])
    refute conn.halted
  end

  test "halts any other host", %{conn: conn} do
    conn = conn |> Map.put(:host, "jamiecurle.com") |> TailnetOnly.call([])
    assert conn.halted
    assert conn.status == 404
  end

  test "halts everything when no host is configured", %{conn: conn} do
    Application.put_env(:jamie, :mcp_host, nil)
    on_exit(fn -> Application.put_env(:jamie, :mcp_host, "stekpi.test") end)

    conn = conn |> Map.put(:host, "stekpi.test") |> TailnetOnly.call([])
    assert conn.halted
  end
end
