defmodule Alkali.Domain.Entities.AssetTest do
  use ExUnit.Case, async: true

  alias Alkali.Domain.Entities.Asset

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

  # NOTE: calculate_fingerprint/1 was moved to Alkali.Infrastructure.CryptoService
  # to follow Clean Architecture - domain entities should not depend on infrastructure.
  # See CryptoService.sha256_fingerprint/1 for fingerprint generation.

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
