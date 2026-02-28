defmodule Perme8DashboardWeb.LayoutsTest do
  use ExUnit.Case, async: true

  @root_layout_path Path.expand(
                      "../../lib/perme8_dashboard_web/components/layouts/root.html.heex",
                      __DIR__
                    )

  describe "root layout (root.html.heex)" do
    test "includes theme detection script that syncs data-theme with device preference" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|prefers-color-scheme: dark|
      assert content =~ ~s|data-theme|
    end

    test "sets bg-base-100 class on body element" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|bg-base-100|
    end

    test "includes CSRF token meta tag" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|csrf-token|
    end

    test "includes live title with Perme8 Dashboard default" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|Perme8 Dashboard|
    end

    test "links to CSS and JS assets" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|/assets/css/app.css|
      assert content =~ ~s|/assets/js/app.js|
    end

    test "renders inner_content" do
      content = File.read!(@root_layout_path)
      assert content =~ ~s|@inner_content|
    end
  end
end
