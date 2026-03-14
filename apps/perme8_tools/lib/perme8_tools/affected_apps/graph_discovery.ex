defmodule Perme8Tools.AffectedApps.GraphDiscovery do
  @moduledoc """
  Discovers umbrella apps and builds the real dependency graph
  by reading mix.exs files from disk.

  This is the only module in the affected_apps library that performs file I/O.
  """

  alias Perme8Tools.AffectedApps.{DependencyGraph, MixExsParser}

  @doc """
  Discovers all umbrella app names by scanning the apps directory.

  Returns a sorted list of app name atoms.
  """
  @spec discover_apps(String.t()) :: [atom()]
  def discover_apps(umbrella_root) do
    apps_dir = Path.join(umbrella_root, "apps")

    case File.ls(apps_dir) do
      {:ok, entries} ->
        entries
        |> Enum.filter(fn entry ->
          path = Path.join(apps_dir, entry)
          File.dir?(path) and File.exists?(Path.join(path, "mix.exs"))
        end)
        |> Enum.map(&String.to_atom/1)
        |> Enum.sort()

      {:error, _} ->
        []
    end
  end

  @doc """
  Builds the full dependency graph by reading all apps' mix.exs files.

  Returns `{:ok, graph}` or `{:error, reason}`.
  """
  @spec build_graph(String.t()) :: {:ok, DependencyGraph.t()} | {:error, term()}
  def build_graph(umbrella_root) do
    apps = discover_apps(umbrella_root)

    deps_map =
      Map.new(apps, fn app ->
        mix_exs_path = Path.join([umbrella_root, "apps", Atom.to_string(app), "mix.exs"])

        deps =
          case File.read(mix_exs_path) do
            {:ok, content} -> MixExsParser.parse_in_umbrella_deps(content)
            {:error, _} -> []
          end

        {app, deps}
      end)

    DependencyGraph.build(deps_map)
  end
end
