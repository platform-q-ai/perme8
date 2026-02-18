defmodule Mix.Tasks.Check.CiSync do
  @shortdoc "Verifies exo-bdd configs are in sync with CI matrix"

  @moduledoc """
  Validates that every exo-bdd config + adapter domain with feature files on
  disk has a corresponding entry in the CI workflow matrix (ALL_COMBOS).

  This prevents accidentally adding a new test adapter (e.g., security) to an
  app's exo-bdd config without wiring it into CI — causing new tests to silently
  never run.

  ## How it works

  1. Discovers all `exo-bdd-*.config.ts` files under `apps/`
  2. For each config, finds `*.{domain}.feature` files on disk (browser, http,
     security, cli, graph) relative to the config's directory
  3. Parses `.github/workflows/ci.yml` to extract the `ALL_COMBOS` Python list
  4. Flags any config+domain pair that has feature files but no CI entry

  ## Usage

      mix check.ci_sync

      # Verbose output showing all detected combos
      mix check.ci_sync --verbose

  ## Exit codes

  - 0: All config+domain combos are in CI
  - 1: Missing CI entries found
  """

  use Mix.Task
  use Boundary, top_level?: true

  @switches [verbose: :boolean]
  @aliases [v: :verbose]

  @known_domains ~w(browser http security cli graph)

  @impl Mix.Task
  def run(args) do
    {opts, _, _} = OptionParser.parse(args, switches: @switches, aliases: @aliases)
    verbose = Keyword.get(opts, :verbose, false)

    umbrella_root = umbrella_root()
    configs = discover_configs(umbrella_root)
    ci_combos = parse_ci_combos(umbrella_root)
    disk_combos = discover_disk_combos(configs, umbrella_root)

    if verbose do
      log_combos("CI matrix entries", ci_combos)
      log_combos("Feature files on disk", disk_combos)
    end

    missing = MapSet.difference(disk_combos, ci_combos)

    if MapSet.size(missing) == 0 do
      Mix.shell().info([
        :green,
        "\n✓ All exo-bdd config+domain combos are in CI (#{MapSet.size(disk_combos)} checked)\n"
      ])
    else
      print_missing(missing, ci_combos)
      exit({:shutdown, 1})
    end
  end

  # ---------------------------------------------------------------------------
  # Disk combo discovery
  # ---------------------------------------------------------------------------

  defp discover_configs(umbrella_root) do
    Path.join(umbrella_root, "apps/**/exo-bdd*.config.ts")
    |> Path.wildcard()
    |> Enum.sort()
  end

  @doc """
  Finds all {config_name, domain} pairs that have at least one matching feature
  file on disk. Uses the config file's directory as the search root for features.
  """
  def discover_disk_combos(config_paths, _umbrella_root) do
    config_paths
    |> Enum.flat_map(fn config_path ->
      config_name = extract_config_name(config_path)
      config_dir = Path.dirname(config_path)

      @known_domains
      |> Enum.filter(fn domain ->
        pattern = Path.join(config_dir, "features/**/*.#{domain}.feature")
        Path.wildcard(pattern) != []
      end)
      |> Enum.map(fn domain -> {config_name, domain} end)
    end)
    |> MapSet.new()
  end

  # ---------------------------------------------------------------------------
  # CI matrix parsing
  # ---------------------------------------------------------------------------

  @doc """
  Parses the ALL_COMBOS Python list from ci.yml and returns a MapSet of
  {config_name, domain} tuples.
  """
  def parse_ci_combos(umbrella_root) do
    ci_path = Path.join(umbrella_root, ".github/workflows/ci.yml")

    unless File.exists?(ci_path) do
      Mix.raise("CI workflow not found at #{ci_path}")
    end

    content = File.read!(ci_path)

    # Extract ALL_COMBOS block: everything between "ALL_COMBOS = [" and the closing "]"
    case Regex.run(~r/ALL_COMBOS\s*=\s*\[(.*?)\]/s, content) do
      [_, combos_block] ->
        parse_combo_entries(combos_block)

      nil ->
        Mix.raise("Could not find ALL_COMBOS list in #{ci_path}")
    end
  end

  defp parse_combo_entries(block) do
    # Each line looks like: {"app": "...", "domain": "...", "config_name": "...", "timeout": N}
    # We extract config_name and domain from each entry.
    Regex.scan(~r/"config_name":\s*"([^"]+)".*?"domain":\s*"([^"]+)"/, block)
    |> Enum.concat(
      Regex.scan(~r/"domain":\s*"([^"]+)".*?"config_name":\s*"([^"]+)"/, block)
      |> Enum.map(fn [full, domain, config_name] -> [full, config_name, domain] end)
    )
    |> Enum.map(fn [_full, config_name, domain] -> {config_name, domain} end)
    |> MapSet.new()
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp extract_config_name(config_path) do
    config_path
    |> Path.basename()
    |> String.replace_prefix("exo-bdd-", "")
    |> String.replace_suffix(".config.ts", "")
    |> String.downcase()
  end

  defp umbrella_root do
    case Mix.Project.config()[:build_path] do
      nil -> File.cwd!()
      build_path -> build_path |> Path.expand() |> Path.dirname()
    end
  end

  defp log_combos(label, combos) do
    sorted = combos |> MapSet.to_list() |> Enum.sort()

    Mix.shell().info([:cyan, "\n#{label} (#{length(sorted)}):\n"])

    Enum.each(sorted, fn {config_name, domain} ->
      Mix.shell().info([:cyan, "  - #{domain} / #{config_name}\n"])
    end)
  end

  defp print_missing(missing, ci_combos) do
    sorted = missing |> MapSet.to_list() |> Enum.sort()

    Mix.shell().error([:red, "\n✗ Exo-BDD Config ↔ CI Matrix Sync Failures:\n"])

    Enum.each(sorted, fn {config_name, domain} ->
      Mix.shell().error([
        :yellow,
        "\n  #{domain} / #{config_name}\n",
        :reset,
        "    Feature files exist for *.#{domain}.feature\n",
        "    but no CI matrix entry found for config_name=\"#{config_name}\", domain=\"#{domain}\"\n"
      ])
    end)

    Mix.shell().error([
      :white,
      "\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n",
      :cyan,
      "To fix, add the missing combo(s) to ALL_COMBOS in .github/workflows/ci.yml:\n\n",
      :reset
    ])

    Enum.each(sorted, fn {config_name, domain} ->
      timeout = if domain == "security", do: "15", else: "10"

      combo_line =
        ~s(  {"app": "#{config_name}", "domain": "#{domain}", ) <>
          ~s("config_name": "#{config_name}", "timeout": #{timeout}},\n)

      Mix.shell().error([:reset, combo_line])
    end)

    existing_count = MapSet.size(ci_combos)
    missing_count = MapSet.size(missing)

    Mix.shell().error([
      :red,
      "\n#{missing_count} missing combo(s) out of #{existing_count + missing_count} total\n"
    ])
  end
end
