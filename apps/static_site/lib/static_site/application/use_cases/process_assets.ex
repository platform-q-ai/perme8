defmodule StaticSite.Application.UseCases.ProcessAssets do
  @moduledoc """
  ProcessAssets use case processes static assets (CSS, JS, binary files),
  minifies them, generates fingerprints, and tracks mappings.
  """

  alias StaticSite.Domain.Entities.Asset

  @doc """
  Processes a list of assets by minifying, fingerprinting, and tracking mappings.

  ## Options

  - `:file_reader` - Function to read file contents (for testing)

  ## Returns

  - `{:ok, %{assets: list(Asset.t()), mappings: map()}}` on success
  - `{:error, String.t()}` on failure
  """
  @spec execute(list(map()), keyword()) ::
          {:ok, %{assets: list(Asset.t()), mappings: map()}} | {:error, String.t()}
  def execute(assets, opts \\ []) do
    file_reader = Keyword.get(opts, :file_reader, &default_file_reader/1)

    results =
      Enum.map(assets, fn asset_map ->
        process_single_asset(asset_map, file_reader)
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
      mappings =
        Enum.reduce(processed_assets, %{}, fn asset, acc ->
          # Map from original path (e.g., "static/css/app.css" -> "css/app-abc123.css")
          acc = Map.put(acc, asset.original_path, asset.output_path)

          # Also map from web path (e.g., "/css/app.css" -> "/css/app-abc123.css")
          # Extract just the filename part after "static/"
          # Handle paths like "kris blog/static/css/app.css" or "static/css/app.css"
          web_path =
            cond do
              # If path contains "/static/", extract everything after it
              String.contains?(asset.original_path, "/static/") ->
                [_, after_static] = String.split(asset.original_path, "/static/", parts: 2)
                "/" <> after_static

              # If path starts with "static/", remove it
              String.starts_with?(asset.original_path, "static/") ->
                asset.original_path
                |> String.replace_prefix("static/", "")
                |> then(&"/#{&1}")

              # Fallback: use as-is with leading slash
              true ->
                "/" <> asset.original_path
            end

          # Remove "_site/" prefix from output path and add leading "/"
          web_output =
            asset.output_path
            |> String.replace_prefix("_site/", "")
            |> then(&"/#{&1}")

          Map.put(acc, web_path, web_output)
        end)

      {:ok, %{assets: processed_assets, mappings: mappings}}
    end
  end

  # Private Functions

  defp process_single_asset(asset_map, file_reader) do
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

          # Generate fingerprint
          fingerprint = Asset.calculate_fingerprint(minified_content)

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

  # Default implementation

  defp default_file_reader(path) do
    case File.read(path) do
      {:ok, content} -> {:ok, content}
      {:error, reason} -> {:error, reason}
    end
  end
end
