defmodule Mix.Tasks.Assets.CopyFonts do
  @moduledoc """
  Copies font files from node_modules to the static assets directory.

  This task ensures that font files referenced in CSS are available
  in the static assets directory for serving by the Phoenix endpoint.
  """
  use Boundary, top_level?: true
  use Mix.Task

  @shortdoc "Copies font files to static assets directory"

  @impl Mix.Task
  def run(_args) do
    # In an umbrella, assets are in apps/jarga_web/assets
    # and priv is in apps/jarga_web/priv
    source_dir =
      Path.join(["apps", "jarga_web", "assets", "node_modules", "@fontsource", "inter", "files"])

    target_dir = Path.join(["apps", "jarga_web", "priv", "static", "assets", "css", "files"])

    # Ensure the target directory exists
    File.mkdir_p!(target_dir)

    # Copy all font files
    source_dir
    |> File.ls!()
    |> Enum.filter(&String.ends_with?(&1, [".woff", ".woff2"]))
    |> Enum.each(fn file ->
      source = Path.join(source_dir, file)
      target = Path.join(target_dir, file)
      File.cp!(source, target)
    end)

    Mix.shell().info("Copied font files to #{target_dir}")
  end
end
