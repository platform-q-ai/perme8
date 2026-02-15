defmodule Mix.Tasks.ExoTest do
  @shortdoc "Runs exo-bdd tests with a given config file"

  @moduledoc """
  Runs exo-bdd BDD tests by shelling out to the exo-bdd CLI runner.

  ## Usage

      # Auto-discover and run all exo-bdd configs under apps/
      mix exo_test

      # Run with a specific config file
      mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts

      # Run with tag filter (merged with config-level tags via AND)
      mix exo_test --tag "@smoke"
      mix exo_test -t "not @security"

      # Filter which config(s) to run by name (substring match)
      mix exo_test --name entity
      mix exo_test -n jarga-api

      # Combine: run only ERM HTTP tests
      mix exo_test --name entity --tag "not @security"

  ## Options

    * `--config` / `-c` - Path to the exo-bdd config file (optional; discovers all configs under apps/ if omitted)
    * `--tag` / `-t` - Cucumber tag expression to filter scenarios (ANDed with config-level tags)
    * `--name` / `-n` - Substring filter for auto-discovered config names

  The config path is resolved relative to the umbrella root.
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [config: :string, tag: :string, name: :string]
  @aliases [c: :config, t: :tag, n: :name]

  @impl Mix.Task
  def run(args) do
    {opts, _rest, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)

    if bun_available?() do
      do_run(opts)
    else
      Mix.shell().info([
        :yellow,
        "Skipping exo-bdd tests: bun is not installed. ",
        "Install bun (https://bun.sh) to run BDD tests.\n"
      ])

      :ok
    end
  end

  defp do_run(opts) do
    umbrella_root = umbrella_root()
    tag = Keyword.get(opts, :tag)
    name = Keyword.get(opts, :name)
    config_paths = resolve_config_paths(opts, umbrella_root, name)

    if config_paths == [] do
      Mix.raise("No exo-bdd configs matched --name #{inspect(name)}")
    end

    if tag, do: Mix.shell().info([:cyan, "CLI tag filter: #{tag}\n"])
    run_configs(config_paths, umbrella_root, tag)
  end

  defp resolve_config_paths(opts, umbrella_root, name) do
    case Keyword.get(opts, :config) do
      nil ->
        configs = discover_configs(umbrella_root)
        filtered = filter_configs(configs, name)
        log_filter_info(filtered, configs, name)
        filtered

      path ->
        [path]
    end
  end

  defp log_filter_info(filtered, configs, name) do
    if name && length(filtered) < length(configs) do
      Mix.shell().info([
        :cyan,
        "Filtered to #{length(filtered)} config(s) matching \"#{name}\"\n"
      ])
    end
  end

  defp run_configs(config_paths, umbrella_root, tag) do
    exo_bdd_root = Path.join(umbrella_root, "tools/exo-bdd")

    Enum.each(config_paths, fn config_path ->
      abs_config = Path.expand(config_path, umbrella_root)
      cmd_args = build_cmd_args(abs_config, tag)

      Mix.shell().info([:cyan, "Running exo-bdd tests with config: #{config_path}\n"])
      run_bun(cmd_args, exo_bdd_root)
    end)

    :ok
  end

  defp run_bun(cmd_args, exo_bdd_root) do
    case System.cmd("bun", cmd_args, cd: exo_bdd_root, into: IO.stream(:stdio, :line)) do
      {_, 0} ->
        Mix.shell().info([:green, "\nExo-BDD tests passed.\n"])

      {_, code} ->
        Mix.raise("exo-bdd tests failed with exit code #{code}")
    end
  rescue
    e in ErlangError ->
      handle_erlang_error(e, __STACKTRACE__)
  end

  defp handle_erlang_error(%ErlangError{original: :enoent}, _stacktrace) do
    Mix.raise(
      "bun is not installed or not in PATH. Install it with: curl -fsSL https://bun.sh/install | bash"
    )
  end

  defp handle_erlang_error(e, stacktrace) do
    reraise e, stacktrace
  end

  defp bun_available? do
    System.find_executable("bun") != nil
  end

  @doc false
  def build_cmd_args(abs_config, tag) do
    base = ["run", "src/cli/index.ts", "run", "--config", abs_config]

    case tag do
      nil -> base
      tag_value -> base ++ ["--tags", tag_value]
    end
  end

  @doc """
  Filters discovered config paths by a substring match (case-insensitive).
  Returns all configs when name is nil.
  """
  def filter_configs(configs, nil), do: configs

  def filter_configs(configs, name) do
    downcased = String.downcase(name)
    Enum.filter(configs, &String.contains?(String.downcase(&1), downcased))
  end

  defp discover_configs(umbrella_root) do
    apps_dir = Path.join(umbrella_root, "apps")

    configs =
      Path.wildcard(Path.join(apps_dir, "**/exo-bdd*.config.ts"))
      |> Enum.map(&Path.relative_to(&1, umbrella_root))
      |> Enum.sort()

    if configs == [] do
      Mix.raise("""
      No exo-bdd config files found under apps/.

      Either provide a config explicitly:

          mix exo_test --config <path-to-config>

      Or create a config file matching the pattern apps/**/exo-bdd*.config.ts
      """)
    end

    Mix.shell().info([:cyan, "Discovered #{length(configs)} exo-bdd config(s):\n"])
    Enum.each(configs, &Mix.shell().info([:cyan, "  - #{&1}\n"]))

    configs
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
end
