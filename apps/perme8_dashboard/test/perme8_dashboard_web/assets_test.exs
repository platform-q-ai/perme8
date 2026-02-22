defmodule Perme8DashboardWeb.AssetsTest do
  use ExUnit.Case, async: true

  @assets_dir Path.expand("../../assets", __DIR__)

  describe "asset pipeline files" do
    test "CSS file exists at expected path" do
      assert File.exists?(Path.join(@assets_dir, "css/app.css"))
    end

    test "JS file exists at expected path" do
      assert File.exists?(Path.join(@assets_dir, "js/app.ts"))
    end

    test "package.json exists" do
      assert File.exists?(Path.join(@assets_dir, "package.json"))
    end

    test "vendor files exist" do
      assert File.exists?(Path.join(@assets_dir, "vendor/topbar.cjs"))
      assert File.exists?(Path.join(@assets_dir, "vendor/heroicons.js"))
      assert File.exists?(Path.join(@assets_dir, "vendor/daisyui.js"))
      assert File.exists?(Path.join(@assets_dir, "vendor/daisyui-theme.js"))
    end

    test "CSS includes Tailwind v4 and DaisyUI dark theme configuration" do
      css_content = File.read!(Path.join(@assets_dir, "css/app.css"))

      assert css_content =~ ~s|@import "tailwindcss"|
      assert css_content =~ ~s|@plugin "../vendor/daisyui"|
      assert css_content =~ ~s|@plugin "../vendor/daisyui-theme"|
      assert css_content =~ ~s|name: "dark"|
    end

    test "JS includes LiveSocket setup and ScrollToHash hook" do
      js_content = File.read!(Path.join(@assets_dir, "js/app.ts"))

      assert js_content =~ "LiveSocket"
      assert js_content =~ "ScrollToHash"
      assert js_content =~ "topbar"
    end
  end

  describe "esbuild and tailwind configuration" do
    test "esbuild profile is configured for perme8_dashboard" do
      esbuild_config = Application.get_env(:esbuild, :perme8_dashboard)

      assert esbuild_config != nil
      assert Keyword.has_key?(esbuild_config, :args)
      assert Keyword.has_key?(esbuild_config, :cd)
    end

    test "tailwind profile is configured for perme8_dashboard" do
      tailwind_config = Application.get_env(:tailwind, :perme8_dashboard)

      assert tailwind_config != nil
      assert Keyword.has_key?(tailwind_config, :args)
      assert Keyword.has_key?(tailwind_config, :cd)
    end
  end
end
