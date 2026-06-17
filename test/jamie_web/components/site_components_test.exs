defmodule JamieWeb.SiteComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.LiveViewTest

  alias JamieWeb.SiteComponents

  describe "pretty_date/1" do
    test "renders day + ordinal suffix + month name + year" do
      html = render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-10])
      assert html =~ "10th May 2026"
    end

    test "uses 'st' for the 1st" do
      html = render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-01])
      assert html =~ "1st May 2026"
    end

    test "uses 'th' for the teens (11th, 12th, 13th)" do
      assert render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-11]) =~ "11th"
      assert render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-12]) =~ "12th"
      assert render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-13]) =~ "13th"
    end

    test "renders a machine-readable datetime attribute" do
      html = render_component(&SiteComponents.pretty_date/1, date: ~D[2026-05-10])
      assert html =~ ~s(datetime="2026-05-10")
    end

    test "renders 'Draft' when the date is nil" do
      html = render_component(&SiteComponents.pretty_date/1, date: nil)
      assert html =~ "Draft"
      refute html =~ "datetime="
    end
  end
end
