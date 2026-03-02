defmodule Perme8DashboardWeb.AppLayoutTest do
  use ExUnit.Case, async: true

  @app_layout_path Path.expand(
                     "../../../lib/perme8_dashboard_web/components/layouts/app.html.heex",
                     __DIR__
                   )

  describe "app layout (app.html.heex)" do
    test "renders 'Perme8 Dashboard' branding" do
      content = File.read!(@app_layout_path)
      assert content =~ "Perme8 Dashboard"
    end

    test "uses tab bar navigation component" do
      content = File.read!(@app_layout_path)
      assert content =~ "tab_bar"
    end

    test "does not use DaisyUI drawer pattern" do
      content = File.read!(@app_layout_path)
      refute content =~ "drawer"
      refute content =~ "drawer-side"
      refute content =~ "data-sidebar-"
    end

    test "renders inner_content" do
      content = File.read!(@app_layout_path)
      assert content =~ "@inner_content"
    end

    test "includes flash_group" do
      content = File.read!(@app_layout_path)
      assert content =~ "flash_group"
    end

    test "data-feature-tree is provided by DashboardLive, not the layout" do
      content = File.read!(@app_layout_path)
      refute content =~ "data-feature-tree"
    end
  end
end
