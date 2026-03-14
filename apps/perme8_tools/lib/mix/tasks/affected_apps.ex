defmodule Mix.Tasks.AffectedApps do
  @shortdoc "Computes affected umbrella apps from changed files"

  @moduledoc """
  Computes which umbrella apps are affected by a set of changed files,
  using the automatically-derived dependency graph.

  ## Usage

      # From explicit file arguments
      mix affected_apps apps/identity/lib/identity.ex config/config.exs

      # From git diff against a base branch
      mix affected_apps --diff main

      # From stdin (pipe)
      git diff --name-only main...HEAD | mix affected_apps

      # JSON output for programmatic consumption
      mix affected_apps --json apps/identity/lib/identity.ex

      # Dry-run mode: show what would be tested
      mix affected_apps --dry-run --diff main

  ## Options

    * `--json` - Output in JSON format for programmatic consumption
    * `--diff BRANCH` - Compute changed files by diffing against a branch
    * `--dry-run` - Show commands that would be run without executing them

  ## Output

  By default, outputs a human-readable summary of affected apps, unit test
  paths, and exo-bdd combos. With `--json`, outputs a machine-readable JSON
  object.
  """

  use Mix.Task
  use Boundary, top_level?: true, deps: [Perme8Tools]

  alias Perme8Tools.AffectedApps.{
    AffectedCalculator,
    DiffProvider,
    ExoBddMapping,
    FileClassifier,
    GraphDiscovery,
    OutputFormatter,
    TestPaths
  }

  @switches [json: :boolean, diff: :string, dry_run: :boolean]
  @aliases [j: :json, d: :diff]

  @impl Mix.Task
  def run(args) do
    {opts, file_args} = parse_args(args)

    umbrella_root = find_umbrella_root()

    # 1. Get changed files
    changed_files = get_changed_files(opts, file_args)

    # 2. Build dependency graph
    {:ok, graph} = GraphDiscovery.build_graph(umbrella_root)
    known_apps = graph |> Perme8Tools.AffectedApps.DependencyGraph.all_apps() |> MapSet.to_list()

    # 3. Classify files
    classification = FileClassifier.classify_all(changed_files, known_apps)

    # 4. Calculate affected apps
    calc_result = AffectedCalculator.calculate(classification, graph)

    # 5. Generate outputs
    unit_paths =
      TestPaths.unit_test_paths(calc_result.affected_apps, all_apps?: calc_result.all_apps?)

    mix_cmd =
      TestPaths.mix_test_command(calc_result.affected_apps, all_apps?: calc_result.all_apps?)

    exo_combos =
      ExoBddMapping.exo_bdd_combos(calc_result.affected_apps,
        all_exo_bdd?: calc_result.all_exo_bdd?
      )

    result = %{
      affected_apps: calc_result.affected_apps,
      all_apps?: calc_result.all_apps?,
      all_exo_bdd?: calc_result.all_exo_bdd?,
      unit_test_paths: unit_paths,
      mix_test_command: mix_cmd,
      exo_bdd_combos: exo_combos
    }

    # 6. Format and output
    output =
      if Keyword.get(opts, :json, false) do
        OutputFormatter.format_json(result)
      else
        format_with_dry_run(result, opts)
      end

    Mix.shell().info(output)
  end

  @doc false
  def parse_args(args) do
    {opts, file_args, _invalid} = OptionParser.parse(args, switches: @switches, aliases: @aliases)
    {opts, file_args}
  end

  # --- Private ---

  defp find_umbrella_root do
    # In an umbrella project, Mix.Project.config()[:apps_path] is set.
    # The umbrella root is two levels up from any app directory.
    case Mix.Project.config()[:apps_path] do
      nil ->
        # We might be running from the umbrella root itself
        cwd = File.cwd!()

        if File.dir?(Path.join(cwd, "apps")) do
          cwd
        else
          # Try going up from an app directory
          Path.expand("../..", cwd)
        end

      _apps_path ->
        # In an umbrella app, go up to the root
        build_path = Mix.Project.config()[:build_path] || "../../_build"
        Path.expand(Path.join(build_path, ".."), File.cwd!())
    end
  end

  defp get_changed_files(opts, file_args) do
    cond do
      Keyword.has_key?(opts, :diff) ->
        base = Keyword.get(opts, :diff)

        case DiffProvider.from_git_diff(base) do
          {:ok, files} -> files
          {:error, err} -> Mix.raise("Failed to get git diff: #{err}")
        end

      file_args != [] ->
        DiffProvider.from_args(file_args)

      true ->
        # Try stdin
        files = DiffProvider.from_stdin()

        if files == [] do
          Mix.raise("""
          No changed files provided. Usage:

            mix affected_apps FILE [FILE...]
            mix affected_apps --diff main
            echo "apps/identity/lib/identity.ex" | mix affected_apps
          """)
        end

        files
    end
  end

  defp format_with_dry_run(result, opts) do
    base = OutputFormatter.format_human(result)

    if Keyword.get(opts, :dry_run, false) do
      commands = build_dry_run_commands(result)

      if commands == "" do
        base
      else
        base <> "\n\n--- Commands (dry-run) ---\n" <> commands
      end
    else
      base
    end
  end

  defp build_dry_run_commands(result) do
    lines = []

    lines =
      if result[:mix_test_command] do
        lines ++ [result.mix_test_command]
      else
        lines
      end

    lines =
      Enum.reduce(result.exo_bdd_combos, lines, fn combo, acc ->
        acc ++ ["mix exo_test --name #{combo.config_name} --adapter #{combo.domain}"]
      end)

    Enum.join(lines, "\n")
  end
end
