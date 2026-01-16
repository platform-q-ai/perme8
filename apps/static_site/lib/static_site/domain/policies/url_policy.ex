defmodule StaticSite.Domain.Policies.UrlPolicy do
  @moduledoc """
  UrlPolicy defines business rules for generating URLs from file paths.

  Pure function with no I/O or side effects.
  """

  @doc """
  Generates a URL from a file path.

  Rules:
  - Removes content directory prefix
  - Preserves folder hierarchy
  - Slugifies the filename (but preserves folder names)
  - Replaces .md extension with .html
  - Ensures URL starts with /

  ## Examples

      iex> UrlPolicy.generate_url("content/posts/my-post.md", "content")
      "/posts/my-post.html"

      iex> UrlPolicy.generate_url("content/posts/2024/01/post.md", "content")
      "/posts/2024/01/post.html"
      
      iex> UrlPolicy.generate_url("content/posts/My First Blog Post.md", "content")
      "/posts/my-first-blog-post.html"
  """
  @spec generate_url(String.t(), String.t()) :: String.t()
  def generate_url(file_path, content_dir) do
    file_path
    |> String.replace_prefix("#{content_dir}/", "")
    |> slugify_filename()
    |> String.replace_suffix(".md", ".html")
    |> ensure_leading_slash()
  end

  # Private Helpers

  defp slugify_filename(path) do
    # Split into directory and filename
    dir = Path.dirname(path)
    filename = Path.basename(path, ".md")

    # Slugify only the filename, preserve directory structure
    slugified_filename = StaticSite.Domain.Policies.SlugPolicy.generate_slug(filename)

    # Recombine
    case dir do
      "." -> "#{slugified_filename}.md"
      _ -> "#{dir}/#{slugified_filename}.md"
    end
  end

  defp ensure_leading_slash("/" <> _ = path), do: path
  defp ensure_leading_slash(path), do: "/" <> path
end
