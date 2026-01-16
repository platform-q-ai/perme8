defmodule Mix.Tasks.StaticSite.Post do
  @shortdoc "Creates a new blog post"

  @moduledoc """
  Creates a new blog post with frontmatter template.

      mix static_site.post "My Post Title" [site_path] [options]

  ## Options

  - `--path` - Path to the site directory (default: current directory)
  - `--date` - Post date (YYYY-MM-DD, defaults to today)
  - `--draft` - Create as draft (default: true in template)

  ## Examples

      mix static_site.post "Getting Started"
      mix static_site.post "Advanced Topics" --date 2024-03-15
      mix static_site.post "My Post" my_blog
      mix static_site.post "My Post" --path my_blog
  """

  use Mix.Task

  @impl true
  def run(args) do
    {options, positional_args, _} =
      OptionParser.parse(args,
        switches: [path: :string, date: :string, draft: :boolean],
        aliases: []
      )

    case positional_args do
      [] ->
        Mix.shell().error("Error: Missing post title")
        Mix.shell().info("Usage: mix static_site.post \"Post Title\" [site_path]")
        Mix.shell().info("   or: mix static_site.post \"Post Title\" --path site_path")
        raise Mix.Error, message: "Missing post title"

      [title] ->
        # Get site path from --path option or use current directory
        site_path = Keyword.get(options, :path, ".")
        create_post(title, site_path, options)

      [title, site_path] ->
        # Support positional site_path argument
        create_post(title, site_path, options)

      _ ->
        Mix.shell().error("Error: Too many arguments")
        Mix.shell().info("Usage: mix static_site.post \"Post Title\" [site_path]")
        Mix.shell().info("   or: mix static_site.post \"Post Title\" --path site_path")
        raise Mix.Error, message: "Too many arguments"
    end
  end

  defp create_post(title, site_path, _options) do
    # For now, just pass site_path - can extend with date/draft options later
    case StaticSite.new_post(title, site_path: site_path) do
      {:ok, %{file_path: file_path}} ->
        Mix.shell().info([
          :green,
          "Created: #{Path.relative_to_cwd(file_path)}",
          :reset
        ])

      {:error, reason} ->
        Mix.shell().error("Error: #{reason}")
        raise Mix.Error, message: reason
    end
  end
end
