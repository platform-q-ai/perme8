defmodule Mix.Tasks.StaticSite.Clean do
  @shortdoc "Cleans the build output directory"

  @moduledoc """
  Removes the build output directory (_site by default).

      mix static_site.clean [site_path]

  ## Arguments

  - `site_path` - Path to the site directory (defaults to current directory)

  ## Examples

      mix static_site.clean
      mix static_site.clean "my_blog"

  This is useful for forcing a complete rebuild from scratch.
  """

  use Mix.Task

  @impl true
  def run(args) do
    # Use first positional argument as site_path, default to "."
    site_path = List.first(args) || "."

    # Construct the output directory path
    output_dir = Path.join([site_path, "_site"])

    case StaticSite.clean_output(output_dir) do
      :ok ->
        Mix.shell().info([:green, "Output directory cleaned: #{output_dir}", :reset])

      {:error, reason} ->
        Mix.shell().error("Error cleaning: #{reason}")
        raise Mix.Error, message: "Failed to clean output directory: #{reason}"
    end
  end
end
