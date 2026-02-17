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

      # Filter which config(s) to run by name (exact match on config stem, then substring)
      mix exo_test --name jarga-web      # exact: only exo-bdd-jarga-web.config.ts
      mix exo_test --name jarga          # substring: matches jarga-web AND jarga-api
      mix exo_test -n relationship        # substring: matches entity-relationship-manager

      # Filter by adapter type (browser, http, cli, security, graph)
      mix exo_test --name jarga-web --adapter browser
      mix exo_test -n identity -a security

      # Combine: run only ERM HTTP tests
      mix exo_test --name entity --tag "not @security"

      # Disable test retries (useful in selective CI mode)
      mix exo_test --name jarga-web --adapter browser --no-retry

  ## Options

    * `--config` / `-c` - Path to the exo-bdd config file (optional; discovers all configs under apps/ if omitted)
    * `--tag` / `-t` - Cucumber tag expression to filter scenarios (ANDed with config-level tags)
    * `--name` / `-n` - Filter by config name stem (exact match preferred, then substring)
    * `--adapter` / `-a` - Filter feature files by adapter type (e.g. browser, http, cli, security, graph)
    * `--no-retry` - Disable test retries (passes `--retry 0` to cucumber-js)

  The config path is resolved relative to the umbrella root.
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [config: :string, tag: :string, name: :string, adapter: :string, no_retry: :boolean]
  @aliases [c: :config, t: :tag, n: :name, a: :adapter]

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
    adapter = Keyword.get(opts, :adapter)
    no_retry = Keyword.get(opts, :no_retry, false)
    config_paths = resolve_config_paths(opts, umbrella_root, name)

    if config_paths == [] do
      Mix.raise("No exo-bdd configs matched --name #{inspect(name)}")
    end

    if tag, do: Mix.shell().info([:cyan, "CLI tag filter: #{tag}\n"])
    if adapter, do: Mix.shell().info([:cyan, "Adapter filter: #{adapter}\n"])
    if no_retry, do: Mix.shell().info([:cyan, "Retries disabled\n"])
    run_configs(config_paths, umbrella_root, tag, adapter, no_retry)
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

  defp run_configs(config_paths, umbrella_root, tag, adapter, no_retry) do
    exo_bdd_root = Path.join(umbrella_root, "tools/exo-bdd")

    Enum.each(config_paths, fn config_path ->
      abs_config = Path.expand(config_path, umbrella_root)
      cmd_args = build_cmd_args(abs_config, tag, adapter, no_retry)

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
  def build_cmd_args(abs_config, tag, adapter \\ nil, no_retry \\ false) do
    base = ["run", "src/cli/index.ts", "run", "--config", abs_config]

    base
    |> maybe_append("--tags", tag)
    |> maybe_append("--adapter", adapter)
    |> maybe_append_flag("--no-retry", no_retry)
  end

  defp maybe_append(args, _flag, nil), do: args
  defp maybe_append(args, flag, value), do: args ++ [flag, value]

  defp maybe_append_flag(args, _flag, false), do: args
  defp maybe_append_flag(args, flag, true), do: args ++ [flag]

  @doc """
  Extracts the config name stem from a config path.

  Given a path like `apps/jarga_web/test/exo-bdd-jarga-web.config.ts`,
  returns `"jarga-web"`.
  """
  def config_name(path) do
    path
    |> Path.basename()
    |> String.replace_prefix("exo-bdd-", "")
    |> String.replace_suffix(".config.ts", "")
    |> String.downcase()
  end

  @doc """
  Filters discovered config paths by name matching (case-insensitive).

  Matching strategy:
  1. Exact match on the config name stem (e.g., `--name jarga-web` matches
     only `exo-bdd-jarga-web.config.ts`)
  2. If no exact match, falls back to substring match on the stem
     (e.g., `--name jarga` matches both `jarga-web` and `jarga-api`)

  Returns all configs when name is nil.
  """
  def filter_configs(configs, nil), do: configs

  def filter_configs(configs, name) do
    downcased = String.downcase(name)

    exact = Enum.filter(configs, &(config_name(&1) == downcased))

    if exact != [] do
      exact
    else
      Enum.filter(configs, &String.contains?(config_name(&1), downcased))
    end
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
