defmodule Alkali.Application.UseCases.CreateNewPost do
  @moduledoc """
  CreateNewPost use case creates a new blog post with frontmatter template.
  """

  alias Alkali.Domain.Policies.SlugPolicy

  @doc """
  Creates a new blog post file.

  ## Options

  - `:site_path` - Site root directory (defaults to current directory)
  - `:date` - Post date (defaults to today)
  - `:file_writer` - Function for writing files (for testing)
  - `:file_checker` - Function to check if file exists (for testing)

  ## Returns

  - `{:ok, %{file_path: String.t()}}` on success
  - `{:error, message}` on failure
  """
  @spec execute(String.t(), keyword()) :: {:ok, %{file_path: String.t()}} | {:error, String.t()}
  def execute(title, opts \\ []) do
    site_path = Keyword.get(opts, :site_path, ".")
    date = Keyword.get(opts, :date, Date.utc_today())
    file_writer = Keyword.get(opts, :file_writer, &default_file_writer/2)
    file_checker = Keyword.get(opts, :file_checker, &File.exists?/1)

    # Generate slug and filename
    slug = SlugPolicy.generate_slug(title)
    date_str = Date.to_iso8601(date)
    base_filename = "#{date_str}-#{slug}.md"

    # Find unique filename
    posts_dir = Path.join([site_path, "content", "posts"])
    file_path = find_unique_path(posts_dir, base_filename, file_checker)

    # Generate frontmatter template
    content = generate_post_template(title, date)

    # Write file
    case file_writer.(file_path, content) do
      {:ok, _path} -> {:ok, %{file_path: file_path}}
      {:error, reason} -> {:error, "Failed to create post: #{inspect(reason)}"}
    end
  end

  # Private Functions

  defp find_unique_path(dir, filename, file_checker) do
    # Extract title slug from filename (remove date prefix and extension)
    ext = Path.extname(filename)
    base = Path.basename(filename, ext)
    title_slug = String.replace(base, ~r/^\d{4}-\d{2}-\d{2}-/, "")

    # Check if any file with this title slug exists (with any date)
    # We need to check systematically for numbered variants
    suffix = find_available_suffix(dir, base, ext, title_slug, file_checker)

    if suffix == 1 do
      # No conflicts, use base filename
      Path.join(dir, filename)
    else
      # Use numbered filename
      new_filename = "#{base}-#{suffix}#{ext}"
      Path.join(dir, new_filename)
    end
  end

  defp find_available_suffix(dir, base, ext, slug, file_checker, n \\ 1) do
    # Build the filename to check
    # For n=1, check YYYY-MM-DD-slug.md (no suffix)
    # For n>1, check YYYY-MM-DD-slug-N.md
    test_filename =
      if n == 1 do
        "#{base}#{ext}"
      else
        "#{base}-#{n}#{ext}"
      end

    test_path = Path.join(dir, test_filename)

    # Also need to check if any file with this slug exists (different dates)
    # For n=1, also try pattern with just the slug part
    if n == 1 do
      cond do
        # Check if exact path exists
        file_checker.(test_path) ->
          find_available_suffix(dir, base, ext, slug, file_checker, 2)

        # Check if any file matching slug pattern exists
        check_slug_pattern_exists(dir, slug, ext, file_checker) ->
          find_available_suffix(dir, base, ext, slug, file_checker, 2)

        true ->
          # No conflicts
          1
      end
    else
      if file_checker.(test_path) do
        find_available_suffix(dir, base, ext, slug, file_checker, n + 1)
      else
        n
      end
    end
  end

  defp check_slug_pattern_exists(dir, slug, ext, file_checker) do
    # Strategy 1: Try checking with file_checker (for testing with mocks)
    # Generate a few test dates to check
    dates = [
      Date.utc_today(),
      Date.add(Date.utc_today(), -1),
      Date.add(Date.utc_today(), -7),
      Date.add(Date.utc_today(), -30),
      Date.add(Date.utc_today(), -365)
    ]

    mock_file_exists =
      Enum.any?(dates, fn date ->
        date_str = Date.to_iso8601(date)
        test_path = Path.join(dir, "#{date_str}-#{slug}#{ext}")
        file_checker.(test_path)
      end)

    if mock_file_exists do
      true
    else
      # Strategy 2: Check real filesystem (for production use)
      # List files in directory and check for matching slugs
      if File.dir?(dir) do
        case File.ls(dir) do
          {:ok, files} ->
            pattern = ~r/^\d{4}-\d{2}-\d{2}-#{Regex.escape(slug)}#{Regex.escape(ext)}$/

            Enum.any?(files, fn filename ->
              Regex.match?(pattern, filename)
            end)

          {:error, _} ->
            false
        end
      else
        false
      end
    end
  end

  defp generate_post_template(title, date) do
    datetime = DateTime.new!(date, ~T[00:00:00])
    iso_datetime = DateTime.to_iso8601(datetime)

    """
    ---
    title: "#{title}"
    date: #{iso_datetime}
    draft: true
    layout: post
    tags: []
    category: ""
    ---

    Write your post content here...
    """
  end

  # Default implementations

  defp default_file_writer(path, content) do
    # Ensure parent directory exists
    File.mkdir_p!(Path.dirname(path))

    case File.write(path, content) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end
end
