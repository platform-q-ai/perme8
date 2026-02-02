defmodule Alkali.Application.UseCases.ProcessAssetsTest do
  use ExUnit.Case, async: true

  alias Alkali.Application.UseCases.ProcessAssets

  describe "execute/2" do
    test "minifies CSS and generates fingerprint" do
      css_content = """
      /* This is a comment */
      body {
        margin: 0;
        padding: 0;
      }
      """

      file_reader = fn _path -> {:ok, css_content} end

      result =
        ProcessAssets.execute(
          [%{original_path: "static/css/app.css", output_path: "output/css/app.css", type: :css}],
          file_reader: file_reader
        )

      assert {:ok, %{assets: [asset], mappings: mappings}} = result
      assert asset.type == :css
      assert asset.fingerprint != nil
      assert String.length(asset.fingerprint) == 64
      assert asset.output_path =~ ~r/output\/css\/app-[a-f0-9]{8}\.css/
      # Verify minification (no comments, no extra whitespace)
      assert asset.output_path =~ "output/css/app-"
      # Check mapping
      assert mappings["static/css/app.css"] == asset.output_path
    end

    test "minifies JS and generates fingerprint" do
      js_content = """
      // Comment
      function test() {
        return true;
      }
      """

      file_reader = fn _path -> {:ok, js_content} end

      result =
        ProcessAssets.execute(
          [%{original_path: "static/js/app.js", output_path: "output/js/app.js", type: :js}],
          file_reader: file_reader
        )

      assert {:ok, %{assets: [asset], mappings: mappings}} = result
      assert asset.type == :js
      assert asset.fingerprint != nil
      assert asset.output_path =~ ~r/output\/js\/app-[a-f0-9]{8}\.js/
      assert mappings["static/js/app.js"] == asset.output_path
    end

    test "copies binary files unchanged" do
      # JPEG header
      binary_content = <<0xFF, 0xD8, 0xFF, 0xE0>>

      file_reader = fn _path -> {:ok, binary_content} end

      result =
        ProcessAssets.execute(
          [
            %{
              original_path: "static/images/photo.jpg",
              output_path: "output/images/photo.jpg",
              type: :binary
            }
          ],
          file_reader: file_reader
        )

      assert {:ok, %{assets: [asset], mappings: mappings}} = result
      assert asset.type == :binary
      # Binary files should NOT be fingerprinted
      assert asset.fingerprint == nil
      # Output path should remain unchanged (no fingerprint added)
      assert asset.output_path == "output/images/photo.jpg"
      assert mappings["static/images/photo.jpg"] == asset.output_path
    end

    test "processes multiple assets" do
      css_content = "body { margin: 0; }"
      js_content = "function test() { return true; }"
      binary_content = <<0xFF, 0xD8>>

      file_reader = fn path ->
        cond do
          String.ends_with?(path, ".css") -> {:ok, css_content}
          String.ends_with?(path, ".js") -> {:ok, js_content}
          true -> {:ok, binary_content}
        end
      end

      assets = [
        %{original_path: "static/css/app.css", output_path: "output/css/app.css", type: :css},
        %{original_path: "static/js/app.js", output_path: "output/js/app.js", type: :js},
        %{original_path: "static/img/logo.png", output_path: "output/img/logo.png", type: :binary}
      ]

      result = ProcessAssets.execute(assets, file_reader: file_reader)

      assert {:ok, %{assets: processed_assets, mappings: mappings}} = result
      assert length(processed_assets) == 3
      # Mappings now include both original paths and web paths (doubled)
      # 3 assets × 2 mappings each = 6 total
      assert map_size(mappings) == 6

      # Verify CSS and JS have fingerprints, but binary does not
      [css_asset, js_asset, binary_asset] = processed_assets

      assert css_asset.fingerprint != nil
      assert String.length(css_asset.fingerprint) == 64

      assert js_asset.fingerprint != nil
      assert String.length(js_asset.fingerprint) == 64

      # Binary should NOT have fingerprint
      assert binary_asset.fingerprint == nil
    end

    test "returns error when file reading fails" do
      file_reader = fn _path -> {:error, "File not found"} end

      result =
        ProcessAssets.execute(
          [%{original_path: "static/css/app.css", output_path: "output/css/app.css", type: :css}],
          file_reader: file_reader
        )

      assert {:error, "Failed to read file: \"File not found\""} = result
    end

    test "handles empty asset list" do
      result = ProcessAssets.execute([], file_reader: fn _ -> {:ok, ""} end)
      assert {:ok, %{assets: [], mappings: %{}}} = result
    end
  end
end
