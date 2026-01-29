defmodule Alkali.Infrastructure.LayoutResolver do
  @moduledoc """
  Resolves and renders layouts for pages.

  Handles layout resolution with the following priority:
  1. Frontmatter `layout` field
  2. Folder-based default (e.g., posts → post.html.heex)
  3. Site default (default.html.heex)

  Implements the `Alkali.Application.Behaviours.LayoutResolverBehaviour` to allow
  dependency injection and testability in use cases.

  All functions accept an optional `opts` keyword list with:
  - `:file_system` - Module implementing file operations (defaults to File)
  """

  @behaviour Alkali.Application.Behaviours.LayoutResolverBehaviour

  # Default file system module for dependency injection
  defp default_file_system, do: File

  @doc """
  Resolves the layout file path for a given page.

  ## Resolution Priority

  1. If page has `layout` in frontmatter, use `layouts/{layout}.html.heex`
  2. If no layout specified, extract folder from URL and try `layouts/{folder}.html.heex`
  3. If folder-based layout doesn't exist, use `layouts/default.html.heex`
  4. Return error if resolved layout doesn't exist

  ## Examples

      iex> page = %{layout: "custom", url: "/posts/my-post"}
      iex> config = %{site_path: "/site", layouts_path: "layouts"}
      iex> resolve_layout(page, config, [])
      {:ok, "/site/layouts/custom.html.heex"}
      
      iex> page = %{layout: nil, url: "/posts/2024/my-post"}
      iex> config = %{site_path: "/site", layouts_path: "layouts"}
      iex> resolve_layout(page, config, [])
      {:ok, "/site/layouts/post.html.heex"}  # if exists, else default
  """
  @impl true
  @spec resolve_layout(map(), map(), keyword()) :: {:ok, String.t()} | {:error, String.t()}
  def resolve_layout(page, config, opts \\ []) do
    file_system = Keyword.get(opts, :file_system, default_file_system())
    site_path = Map.get(config, :site_path, ".")
    layouts_path = Map.get(config, :layouts_path, "layouts")

    layout_file =
      if page.layout != nil do
        # Priority 1: Frontmatter layout
        "#{page.layout}.html.heex"
      else
        # Priority 2: Folder-based default
        resolve_folder_based_layout(page.url, site_path, layouts_path, file_system)
      end

    # Build full path and verify it exists
    layout_path = Path.join([site_path, layouts_path, layout_file])

    if file_system.exists?(layout_path) do
      {:ok, layout_path}
    else
      # Extract layout name without extension for error message
      layout_name = Path.basename(layout_file, ".html.heex")

      # Get relative path from page if available
      page_path =
        case Map.get(page, :file_path) do
          nil ->
            nil

          file_path ->
            file_path
            |> Path.split()
            |> Enum.drop_while(&(&1 not in ["content", "posts", "pages"]))
            |> Path.join()
        end

      error_msg =
        if page_path do
          "Layout '#{layout_name}' not found\nReferenced in: #{page_path}\nLooked in: #{layout_path}"
        else
          "Layout '#{layout_name}' not found\nLooked in: #{layout_path}"
        end

      {:error, error_msg}
    end
  end

  @doc """
  Extracts the top-level folder name from a URL.

  Used for folder-based layout resolution.

  ## Examples

      iex> extract_folder_from_url("/posts/2024/my-post")
      "posts"
      
      iex> extract_folder_from_url("/pages/about")
      "pages"
      
      iex> extract_folder_from_url("/about")
      "page"
  """
  @impl true
  @spec extract_folder_from_url(String.t()) :: String.t()
  def extract_folder_from_url(url) do
    case String.split(url, "/", trim: true) do
      # Multi-segment URL: extract first folder
      [folder, _second | _rest] when byte_size(folder) > 0 -> folder
      # Single segment: return "page" for root-level URLs like "/about"
      [_single] -> "page"
      # Empty: return "page"
      [] -> "page"
    end
  end

  @doc """
  Renders a page with its layout template.

  ## Parameters

  - `page` - Page struct/map with content and metadata
  - `layout_path` - Full path to layout file
  - `config` - Site configuration map
  - `opts` - Additional rendering options

  ## Returns

  - `{:ok, html}` - Rendered HTML string
  - `{:error, reason}` - Error message

  ## Examples

      iex> page = %{title: "My Post", content: "<p>Hello</p>"}
      iex> layout_path = "/site/layouts/post.html.heex"
      iex> config = %{site_name: "My Blog"}
      iex> render_with_layout(page, layout_path, config, [])
      {:ok, "<html>...</html>"}
  """
  @impl true
  @spec render_with_layout(map(), String.t(), map(), keyword()) ::
          {:ok, String.t()} | {:error, String.t()}
  def render_with_layout(page, layout_path, config, opts \\ []) do
    file_system = Keyword.get(opts, :file_system, default_file_system())

    case file_system.read(layout_path) do
      {:ok, layout_template} ->
        # Get layouts directory from layout_path
        layouts_dir = Path.dirname(layout_path)

        # Preprocess template to replace render_partial calls
        # This is a simple approach - in production you'd want a proper parser
        processed_template = preprocess_partials(layout_template, layouts_dir, file_system)

        # Prepare assigns for template
        assigns = %{
          page: page,
          site: Map.get(config, :site, %{}),
          content: Map.get(page, :content, "")
        }

        # Merge any additional assigns from opts
        assigns =
          Enum.reduce(opts, assigns, fn
            {:assigns, extra_assigns}, acc -> Map.merge(acc, extra_assigns)
            _other, acc -> acc
          end)

        # Render with EEx
        html = EEx.eval_string(processed_template, assigns: assigns)

        # Replace asset references with fingerprinted versions
        asset_mappings = Keyword.get(opts, :asset_mappings, %{})
        html_with_assets = replace_asset_references(html, asset_mappings)

        {:ok, html_with_assets}

      {:error, reason} ->
        {:error, "Failed to read layout: #{inspect(reason)}"}
    end
  end

  # Private helpers

  defp resolve_folder_based_layout(url, site_path, layouts_path, file_system) do
    folder = extract_folder_from_url(url)

    # Try both plural and singular forms
    # E.g., "posts" → try "posts.html.heex", then "post.html.heex"
    singular_folder = singularize(folder)

    folder_layout = "#{folder}.html.heex"
    folder_layout_path = Path.join([site_path, layouts_path, folder_layout])

    singular_layout = "#{singular_folder}.html.heex"
    singular_layout_path = Path.join([site_path, layouts_path, singular_layout])

    cond do
      file_system.exists?(folder_layout_path) -> folder_layout
      file_system.exists?(singular_layout_path) -> singular_layout
      true -> "default.html.heex"
    end
  end

  # Replaces asset references in HTML with fingerprinted versions
  defp replace_asset_references(html, asset_mappings) do
    Enum.reduce(asset_mappings, html, fn {original, fingerprinted}, acc ->
      # Replace all occurrences of the original path with the fingerprinted path
      String.replace(acc, original, fingerprinted)
    end)
  end

  @doc false
  # Preprocesses template to replace render_partial calls with actual partial content
  defp preprocess_partials(template, layouts_dir, file_system) do
    # Find all render_partial calls using regex
    # Pattern: <%= render_partial("partial_name", assigns) %>
    # Also handles: <%= render_partial("partial_name",assigns) %>
    regex = ~r/<%= render_partial\("([^"]+)",\s*assigns\) ?%>/

    Regex.replace(regex, template, fn _, partial_name ->
      # Read and return the partial content
      partials_dir = Path.join(layouts_dir, "partials")
      partial_path = Path.join(partials_dir, partial_name)

      case file_system.read(partial_path) do
        {:ok, partial_content} ->
          # Return the partial content directly (it will be part of the template)
          String.trim(partial_content)

        {:error, _} ->
          # Return empty if partial not found
          ""
      end
    end)
  end

  # Simple singularization for common plural forms
  defp singularize(word) do
    cond do
      String.ends_with?(word, "ies") ->
        String.slice(word, 0..-4//1) <> "y"

      String.ends_with?(word, "ses") || String.ends_with?(word, "xes") ->
        String.slice(word, 0..-3//1)

      String.ends_with?(word, "s") ->
        String.slice(word, 0..-2//1)

      true ->
        word
    end
  end
end
