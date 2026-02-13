defmodule Mix.Tasks.ExoTest do
  @shortdoc "Runs exo-bdd tests with a given config file"

  @moduledoc """
  Runs exo-bdd BDD tests by shelling out to the exo-bdd CLI runner.

  ## Usage

      # Run with a config file
      mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts

      # Run with tag filter
      mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts --tag @smoke

  ## Options

    * `--config` / `-c` - Path to the exo-bdd config file (required)
    * `--tag` / `-t` - Cucumber tag expression to filter scenarios

  The config path is resolved relative to the umbrella root.
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [config: :string, tag: :string]
  @aliases [c: :config, t: :tag]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    config_path = Keyword.get(opts, :config) || raise_missing_config()

    umbrella_root = umbrella_root()
    abs_config = Path.expand(config_path, umbrella_root)
    exo_bdd_root = Path.join(umbrella_root, "tools/exo-bdd")

    cmd_args = build_cmd_args(abs_config, Keyword.get(opts, :tag))

    Mix.shell().info([:cyan, "Running exo-bdd tests with config: #{config_path}\n"])

    case System.cmd("bun", cmd_args, cd: exo_bdd_root, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info([:green, "\nExo-BDD tests passed.\n"])
        :ok

      {_, code} ->
        Mix.raise("exo-bdd tests failed with exit code #{code}")
    end
  end

  @doc false
  def build_cmd_args(abs_config, tag) do
    base = ["run", "src/cli/index.ts", "run", "--config", abs_config]

    case tag do
      nil -> base
      tag_value -> base ++ ["--tags", tag_value]
    end
  end

  defp umbrella_root do
    case Mix.Project.config()[:build_path] do
      nil ->
        # Running from umbrella root -- cwd is the root
        File.cwd!()

      build_path ->
        # In an umbrella child app, build_path is "../../_build" relative to the app.
        # Resolving it and going one level up gives us the umbrella root.
        build_path
        |> Path.expand()
        |> Path.dirname()
    end
  end

  defp raise_missing_config do
    Mix.raise("""
    Missing required --config option.

    Usage: mix exo_test --config <path-to-config>

    Example: mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts
    """)
  end
end
