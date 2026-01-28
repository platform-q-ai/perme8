defmodule Mix.Tasks.Alkali.New.Post do
  @shortdoc "Creates a new blog post"

  @moduledoc """
  Creates a new blog post with frontmatter template.

      mix alkali.new.post "Post Title" [site_path]
      mix alkali.new.post "Post Title" --path site_path

  The post will be created in content/posts/ with a filename based on
  the current date and the slugified title.

  ## Options

  - `--path` - Path to the site directory (default: current directory)

  ## Examples

      mix alkali.new.post "Getting Started with Elixir"
      # Creates: content/posts/2024-01-15-getting-started-with-elixir.md

      mix alkali.new.post "My Post" my_blog
      # Creates: my_blog/content/posts/2024-01-15-my-post.md

      mix alkali.new.post "My Post" --path my_blog
      # Creates: my_blog/content/posts/2024-01-15-my-post.md

  If a post with the same filename already exists, a number suffix will be
  added automatically (e.g., -2, -3, etc.).
  """

  use Mix.Task

  alias Alkali.Application.UseCases.CreateNewPost

  @impl true
  def run(args) do
    {options, positional_args, _} =
      OptionParser.parse(args,
        switches: [path: :string],
        aliases: []
      )

    case positional_args do
      [title] ->
        # Get site path from --path option or use current directory
        site_path = Keyword.get(options, :path, ".")

        # Delegate to use case with site_path
        case CreateNewPost.execute(title, site_path: site_path) do
          {:ok, %{file_path: file_path}} ->
            Mix.shell().info([
              :green,
              "Created new post: ",
              :reset,
              Path.relative_to_cwd(file_path)
            ])

          {:error, reason} ->
            Mix.shell().error("Error creating post: #{reason}")
            raise Mix.Error, message: "Failed to create post: #{reason}"
        end

      [title, site_path] ->
        # Support positional site_path argument
        case CreateNewPost.execute(title, site_path: site_path) do
          {:ok, %{file_path: file_path}} ->
            Mix.shell().info([
              :green,
              "Created new post: ",
              :reset,
              Path.relative_to_cwd(file_path)
            ])

          {:error, reason} ->
            Mix.shell().error("Error creating post: #{reason}")
            raise Mix.Error, message: "Failed to create post: #{reason}"
        end

      [] ->
        Mix.shell().error("Error: Missing post title")
        Mix.shell().info("Usage: mix alkali.new.post \"Post Title\" [site_path]")
        Mix.shell().info("   or: mix alkali.new.post \"Post Title\" --path site_path")
        raise Mix.Error, message: "Missing post title"

      _ ->
        Mix.shell().error("Error: Too many arguments")
        Mix.shell().info("Usage: mix alkali.new.post \"Post Title\" [site_path]")
        Mix.shell().info("   or: mix alkali.new.post \"Post Title\" --path site_path")
        raise Mix.Error, message: "Too many arguments"
    end
  end
end
