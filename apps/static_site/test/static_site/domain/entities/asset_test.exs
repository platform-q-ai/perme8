defmodule StaticSite.Domain.Entities.AssetTest do
  use ExUnit.Case, async: true

  alias StaticSite.Domain.Entities.Asset

  describe "new/1" do
    test "creates an asset with paths and type" do
      attrs = %{
        original_path: "static/css/app.css",
        output_path: "_site/css/app-abc123.css",
        type: :css
      }

      asset = Asset.new(attrs)

      assert asset.original_path == "static/css/app.css"
      assert asset.output_path == "_site/css/app-abc123.css"
      assert asset.type == :css
      assert asset.fingerprint == nil
    end

    test "creates a JavaScript asset" do
      attrs = %{
        original_path: "static/js/app.js",
        output_path: "_site/js/app-def456.js",
        type: :js
      }

      asset = Asset.new(attrs)

      assert asset.type == :js
    end

    test "creates a binary asset (image, etc.)" do
      attrs = %{
        original_path: "static/images/logo.png",
        output_path: "_site/images/logo.png",
        type: :binary
      }

      asset = Asset.new(attrs)

      assert asset.type == :binary
    end
  end

  describe "calculate_fingerprint/1" do
    test "generates SHA256 fingerprint from content" do
      content = "body { margin: 0; }"

      fingerprint = Asset.calculate_fingerprint(content)

      assert is_binary(fingerprint)
      assert String.length(fingerprint) == 64
      # SHA256 produces a 64-character hex string
    end

    test "generates consistent fingerprints for same content" do
      content = "console.log('hello');"

      fingerprint1 = Asset.calculate_fingerprint(content)
      fingerprint2 = Asset.calculate_fingerprint(content)

      assert fingerprint1 == fingerprint2
    end

    test "generates different fingerprints for different content" do
      content1 = "body { margin: 0; }"
      content2 = "body { padding: 0; }"

      fingerprint1 = Asset.calculate_fingerprint(content1)
      fingerprint2 = Asset.calculate_fingerprint(content2)

      assert fingerprint1 != fingerprint2
    end
  end

  describe "with_fingerprint/2" do
    test "adds fingerprint to asset" do
      asset =
        Asset.new(%{
          original_path: "static/css/app.css",
          output_path: "_site/css/app.css",
          type: :css
        })

      fingerprint = "abc123def456"
      asset_with_fp = Asset.with_fingerprint(asset, fingerprint)

      assert asset_with_fp.fingerprint == "abc123def456"
    end

    test "updates output path with fingerprint" do
      asset =
        Asset.new(%{
          original_path: "static/css/app.css",
          output_path: "_site/css/app.css",
          type: :css
        })

      fingerprint = "abc123"
      asset_with_fp = Asset.with_fingerprint(asset, fingerprint)

      assert asset_with_fp.output_path == "_site/css/app-abc123.css"
    end

    test "handles JS files" do
      asset =
        Asset.new(%{
          original_path: "static/js/app.js",
          output_path: "_site/js/app.js",
          type: :js
        })

      fingerprint = "def456"
      asset_with_fp = Asset.with_fingerprint(asset, fingerprint)

      assert asset_with_fp.output_path == "_site/js/app-def456.js"
    end
  end
end
