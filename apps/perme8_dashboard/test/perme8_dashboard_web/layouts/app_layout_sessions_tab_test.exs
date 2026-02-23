defmodule Perme8DashboardWeb.AppLayoutSessionsTabTest do
  use ExUnit.Case, async: true

  @app_layout_path Path.expand(
                     "../../../lib/perme8_dashboard_web/components/layouts/app.html.heex",
                     __DIR__
                   )

  describe "app layout sessions tab" do
    test "contains 'Sessions' tab label" do
      content = File.read!(@app_layout_path)
      assert content =~ "Sessions"
    end

    test "contains sessions tab key in tabs config" do
      content = File.read!(@app_layout_path)
      assert content =~ ":sessions"
    end

    test "contains sessions path in tabs config" do
      content = File.read!(@app_layout_path)
      assert content =~ ~s(~p"/sessions")
    end

    test "contains hero-chat-bubble-left-right icon for sessions" do
      content = File.read!(@app_layout_path)
      assert content =~ "hero-chat-bubble-left-right"
    end

    test "sidebar navigation includes data-sidebar-sessions attribute" do
      content = File.read!(@app_layout_path)
      assert content =~ "data-sidebar-"
    end

    test "features tab is still present" do
      content = File.read!(@app_layout_path)
      assert content =~ ":features"
      assert content =~ ~s("Features")
    end
  end
end
