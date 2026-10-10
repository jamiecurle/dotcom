defmodule JamieWeb.FlashTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JamieWeb.CoreComponents

  defp render_flash(kind, message) do
    html =
      render_component(&CoreComponents.flash/1, kind: kind, flash: %{to_string(kind) => message})

    LazyHTML.from_fragment(html)
  end

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  test "toasts sit bottom right" do
    doc = render_flash(:info, "Saved")

    assert count(doc, "#flash-info.toast.toast-bottom.toast-end") == 1
    assert count(doc, ".toast-top") == 0
  end

  test "an info toast counts itself down" do
    doc = render_flash(:info, "Saved")

    assert count(doc, "#flash-info[phx-hook='FlashDismiss']") == 1
    assert count(doc, "#flash-info .toast-close .toast-countdown") == 1
  end

  test "an error toast stays until it's clicked" do
    doc = render_flash(:error, "Nope")

    assert count(doc, "#flash-error[phx-hook]") == 0
    assert count(doc, "#flash-error .toast-countdown") == 0
    assert count(doc, "#flash-error .toast-close .hero-x-mark") == 1
  end
end
