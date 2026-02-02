defmodule Alkali.Application.UseCases.ParseContent do
  @moduledoc """
  ParseContent use case parses markdown files and creates Page entities.
  """

  alias Alkali.Domain.Entities.Page
  alias Alkali.Domain.Policies.{SlugPolicy, UrlPolicy, FrontmatterPolicy}

  # Infrastructure module defaults - resolved at runtime to avoid boundary violations
  defp default_file_system_mod, do: Alkali.Infrastructure.FileSystem
  defp default_frontmatter_parser_mod, do: Alkali.Infrastructure.Parsers.FrontmatterParser
  defp default_markdown_parser_mod, do: Alkali.Infrastructure.Parsers.MarkdownParser

  @doc """
  Parses content files and generates Page entities.

  ## Options

  - `:content_loader` - Function to load markdown files
  - `:frontmatter_parser` - Function to parse frontmatter
  - `:markdown_parser` - Function to render markdown to HTML

  ## Returns

  - `{:ok, %{pages: list(Page.t()), stats: map()}}` on success
  - `{:error, message}` on validation failure or duplicate slugs
  """
  @spec execute(String.t(), keyword()) ::
          {:ok, %{pages: list(Page.t()), stats: map()}} | {:error, String.t()}
  def execute(content_path, opts \\ []) do
    content_loader = Keyword.get(opts, :content_loader, &default_content_loader/1)
    frontmatter_parser = Keyword.get(opts, :frontmatter_parser, &default_frontmatter_parser/1)
    markdown_parser = Keyword.get(opts, :markdown_parser, &default_markdown_parser/1)

    # Expand content_path to absolute to ensure consistency with file paths from Path.wildcard
    absolute_content_path = Path.expand(content_path)

    # Load all markdown files
    case content_loader.(absolute_content_path) do
      {:ok, files} ->
        parse_files(files, absolute_content_path, frontmatter_parser, markdown_parser)

      {:error, reason} ->
        {:error, "Failed to load content: #{inspect(reason)}"}
    end
  end

  # Private Functions

  defp parse_files(files, content_path, frontmatter_parser, markdown_parser) do
    results =
      Enum.map(files, fn {file_path, content, _mtime} ->
        parse_single_file(file_path, content, content_path, frontmatter_parser, markdown_parser)
      end)

    # Check for errors
    errors = Enum.filter(results, &match?({:error, _}, &1))

    if Enum.any?(errors) do
      {:error, elem(hd(errors), 1)}
    else
      pages = Enum.map(results, fn {:ok, page} -> page end)

      # Check for duplicate slugs
      case check_duplicate_slugs(pages) do
        :ok ->
          stats = calculate_stats(pages)
          {:ok, %{pages: pages, stats: stats}}

        {:error, message} ->
          {:error, message}
      end
    end
  end

  defp parse_single_file(file_path, content, content_path, frontmatter_parser, markdown_parser) do
    with {:ok, {frontmatter, markdown}} <- frontmatter_parser.(content),
         {:ok, validated_fm} <- FrontmatterPolicy.validate_frontmatter(frontmatter),
         html <- markdown_parser.(markdown) do
      # Extract filename and generate slug/URL
      slug = generate_slug_from_path(file_path)
      url = UrlPolicy.generate_url(file_path, content_path)

      # Create Page entity
      page =
        Page.from_frontmatter(validated_fm, html)
        |> Map.put(:slug, slug)
        |> Map.put(:url, url)
        |> Map.put(:file_path, file_path)

      {:ok, page}
    else
      {:error, reasons} when is_list(reasons) ->
        # Get relative path from file_path (remove any leading directory paths)
        relative_path =
          file_path
          |> Path.split()
          |> Enum.drop_while(&(&1 not in ["content", "posts", "pages"]))
          |> Path.join()

        # Format each error with the file path
        formatted_errors =
          Enum.map_join(reasons, "; ", fn reason -> "#{reason} in #{relative_path}" end)

        {:error, formatted_errors}

      {:error, reason} ->
        {:error, "Error parsing #{file_path}: #{inspect(reason)}"}
    end
  end

  defp generate_slug_from_path(file_path) do
    file_path
    |> Path.basename(".md")
    |> String.replace(~r/^\d{4}-\d{2}-\d{2}-/, "")
    |> SlugPolicy.generate_slug()
  end

  defp check_duplicate_slugs(pages) do
    slug_counts =
      pages
      |> Enum.group_by(& &1.slug)
      |> Enum.filter(fn {_slug, pages} -> length(pages) > 1 end)

    case slug_counts do
      [] ->
        :ok

      duplicates ->
        {slug, conflicting_pages} = hd(duplicates)

        # Format file list
        file_list =
          Enum.map_join(conflicting_pages, "\n", fn page ->
            # Get relative path from file_path
            relative_path =
              page.file_path
              |> Path.split()
              |> Enum.drop_while(&(&1 not in ["content", "posts", "pages"]))
              |> Path.join()

            "  - #{relative_path}"
          end)

        {:error, "Duplicate slug detected: '#{slug}'\nConflicting files:\n#{file_list}"}
    end
  end

  defp calculate_stats(pages) do
    %{
      total_files: length(pages),
      drafts: Enum.count(pages, & &1.draft)
    }
  end

  # Default implementations

  defp default_content_loader(path) do
    default_file_system_mod().load_markdown_files(path)
  end

  defp default_frontmatter_parser(content) do
    default_frontmatter_parser_mod().parse(content)
  end

  defp default_markdown_parser(markdown) do
    default_markdown_parser_mod().parse(markdown)
  end
end
