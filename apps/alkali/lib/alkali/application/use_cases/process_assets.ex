defmodule Alkali.Application.UseCases.ProcessAssets do
  @moduledoc """
  ProcessAssets use case processes static assets (CSS, JS, binary files),
  minifies them, generates fingerprints, and tracks mappings.
  """

  alias Alkali.Domain.Entities.Asset
  alias Alkali.Infrastructure.CryptoService
  alias Alkali.Infrastructure.FileSystem

  @doc """
  Processes a list of assets by minifying, fingerprinting, and tracking mappings.

  ## Options

  - `:file_reader` - Function to read file contents (for testing)
  - `:crypto_service` - Module for cryptographic operations (for testing)

  ## Returns

  - `{:ok, %{assets: list(Asset.t()), mappings: map()}}` on success
  - `{:error, String.t()}` on failure
  """
  @spec execute(list(map()), keyword()) ::
          {:ok, %{assets: list(Asset.t()), mappings: map()}} | {:error, String.t()}
  def execute(assets, opts \\ []) do
    file_reader = Keyword.get(opts, :file_reader, &default_file_reader/1)
    crypto_service = Keyword.get(opts, :crypto_service, CryptoService)

    results =
      Enum.map(assets, fn asset_map ->
        process_single_asset(asset_map, file_reader, crypto_service)
      end)

    # Check for errors
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.any?(errors) do
      {:error, elem(hd(errors), 1)}
    else
      # Extract processed assets
      processed_assets = Enum.map(results, fn {:ok, asset} -> asset end)

      # Build mappings
      # Map both the original path AND the web path (without "static/" prefix) to output
      mappings = build_asset_mappings(processed_assets)

      {:ok, %{assets: processed_assets, mappings: mappings}}
    end
  end

  # Private Functions

  defp build_asset_mappings(assets) do
    Enum.reduce(assets, %{}, fn asset, acc ->
      acc
      |> Map.put(asset.original_path, asset.output_path)
      |> Map.put(extract_web_path(asset.original_path), extract_web_output(asset.output_path))
    end)
  end

  defp extract_web_path(original_path) do
    cond do
      String.contains?(original_path, "/static/") ->
        [_, after_static] = String.split(original_path, "/static/", parts: 2)
        "/" <> after_static

      String.starts_with?(original_path, "static/") ->
        "/" <> String.replace_prefix(original_path, "static/", "")

      true ->
        "/" <> original_path
    end
  end

  defp extract_web_output(output_path) do
    "/" <> String.replace_prefix(output_path, "_site/", "")
  end

  defp process_single_asset(asset_map, file_reader, crypto_service) do
    original_path = asset_map.original_path
    output_path = asset_map.output_path
    type = asset_map.type

    case file_reader.(original_path) do
      {:ok, content} ->
        # For binary assets, don't minify or fingerprint - just copy as-is
        if type == :binary do
          asset =
            Asset.new(%{
              original_path: original_path,
              output_path: output_path,
              type: type,
              content: content
            })

          {:ok, asset}
        else
          # Minify content for CSS/JS
          minified_content = minify_content(content, type)

          # Generate fingerprint using injected crypto service
          fingerprint = crypto_service.sha256_fingerprint(minified_content)

          # Create Asset entity with fingerprint and content
          asset =
            Asset.new(%{
              original_path: original_path,
              output_path: output_path,
              type: type,
              content: minified_content
            })
            |> Asset.with_fingerprint(fingerprint)

          {:ok, asset}
        end

      {:error, reason} ->
        {:error, "Failed to read file: #{inspect(reason)}"}
    end
  end

  defp minify_content(content, :css) do
    content
    # Remove /* comments */
    |> String.replace(~r/\/\*[\s\S]*?\*\//m, "")
    # Collapse whitespace
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp minify_content(content, :js) do
    content
    # Remove // comments (to end of line)
    |> String.replace(~r/\/\/.*$/m, "")
    # Collapse whitespace
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  defp minify_content(content, :binary), do: content

  # Default implementation delegating to infrastructure

  defp default_file_reader(path) do
    FileSystem.read(path)
  end
end
