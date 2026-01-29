defmodule Mix.Tasks.Alkali.New do
  @shortdoc "Creates a new static site"

  @moduledoc """
  Creates a new static site with starter templates and example content.

      mix alkali.new my_blog

  This will create a new directory `my_blog` with:

  - config/alkali.exs - Site configuration
  - content/ - Content directory with example files
  - layouts/ - Layout templates
  - static/ - Static assets (CSS, JS, images)

  ## Options

  - `--path` - Custom path for the new site (default: current directory)

  ## Examples

      mix alkali.new my_blog
      mix alkali.new my_docs --path ~/projects
  """

  use Mix.Task
  use Boundary, top_level?: true, deps: [Alkali]

  @impl true
  def run(args) do
    {options, positional_args, _} =
      OptionParser.parse(args,
        switches: [path: :string],
        aliases: []
      )

    case positional_args do
      [name] ->
        base_path = Keyword.get(options, :path, ".")

        case Alkali.new_site(name, target_path: base_path) do
          {:ok, summary} ->
            Mix.shell().info([:green, "✓ ", :reset, "Successfully created #{name}!"])
            Mix.shell().info("")
            Mix.shell().info("Next steps:")
            Mix.shell().info("  cd #{name}")
            Mix.shell().info("  mix alkali.build")
            Mix.shell().info("")
            Mix.shell().info("Your site will be generated in _site/")
            Mix.shell().info("")
            Mix.shell().info("Created:")
            Mix.shell().info("  - #{length(summary.created_dirs)} directories")
            Mix.shell().info("  - #{length(summary.created_files)} files")

          {:error, message} ->
            Mix.shell().error("Error: #{message}")
            raise Mix.Error, message: message
        end

      [] ->
        Mix.shell().error("Error: Missing site name")
        Mix.shell().info("Usage: mix alkali.new <name>")
        raise Mix.Error, message: "Missing site name"

      _ ->
        Mix.shell().error("Error: Too many arguments")
        Mix.shell().info("Usage: mix alkali.new <name>")
        raise Mix.Error, message: "Too many arguments"
    end
  end
end
