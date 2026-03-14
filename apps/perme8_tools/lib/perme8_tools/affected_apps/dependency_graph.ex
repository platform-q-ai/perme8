defmodule Perme8Tools.AffectedApps.DependencyGraph do
  @moduledoc """
  Builds and queries a directed acyclic graph of umbrella app dependencies.

  The graph stores both forward (adjacency) and reverse (dependents) edges,
  enabling efficient transitive dependency lookups. Circular dependencies
  are detected during construction.
  """

  defstruct adjacency: %{}, reverse: %{}

  @type t :: %__MODULE__{
          adjacency: %{atom() => MapSet.t(atom())},
          reverse: %{atom() => MapSet.t(atom())}
        }

  @doc """
  Builds a dependency graph from a map of `%{app_name => [dependency_atoms]}`.

  Returns `{:ok, graph}` if the graph is acyclic, or
  `{:error, :circular_dependency, cycle}` if a cycle is detected.

  ## Examples

      iex> {:ok, graph} = DependencyGraph.build(%{a: [:b], b: [], c: [:a]})
      iex> DependencyGraph.all_apps(graph)
      MapSet.new([:a, :b, :c])
  """
  @spec build(%{atom() => [atom()]}) :: {:ok, t()} | {:error, :circular_dependency, [atom()]}
  def build(deps_map) when is_map(deps_map) do
    adjacency =
      Map.new(deps_map, fn {app, deps} ->
        {app, MapSet.new(deps)}
      end)

    reverse = build_reverse(adjacency)

    graph = %__MODULE__{adjacency: adjacency, reverse: reverse}

    case detect_cycle(graph) do
      nil -> {:ok, graph}
      cycle -> {:error, :circular_dependency, cycle}
    end
  end

  @doc """
  Returns the set of apps that directly depend on `app`.
  """
  @spec direct_dependents(t(), atom()) :: MapSet.t(atom())
  def direct_dependents(%__MODULE__{reverse: reverse}, app) do
    Map.get(reverse, app, MapSet.new())
  end

  @doc """
  Returns all apps that directly or transitively depend on `app`.

  Uses BFS on the reverse adjacency graph.
  """
  @spec transitive_dependents(t(), atom()) :: MapSet.t(atom())
  def transitive_dependents(%__MODULE__{reverse: reverse}, app) do
    bfs(reverse, app)
  end

  @doc """
  Returns all apps in the graph.
  """
  @spec all_apps(t()) :: MapSet.t(atom())
  def all_apps(%__MODULE__{adjacency: adjacency}) do
    adjacency |> Map.keys() |> MapSet.new()
  end

  @doc """
  Returns the direct dependencies of `app` (what `app` depends ON).
  """
  @spec dependencies(t(), atom()) :: MapSet.t(atom())
  def dependencies(%__MODULE__{adjacency: adjacency}, app) do
    Map.get(adjacency, app, MapSet.new())
  end

  # --- Private ---

  defp build_reverse(adjacency) do
    # Initialize all apps with empty sets
    initial = Map.new(adjacency, fn {app, _} -> {app, MapSet.new()} end)

    Enum.reduce(adjacency, initial, fn {app, deps}, acc ->
      Enum.reduce(deps, acc, fn dep, inner_acc ->
        Map.update(inner_acc, dep, MapSet.new([app]), &MapSet.put(&1, app))
      end)
    end)
  end

  defp bfs(reverse, start) do
    queue = :queue.from_list(MapSet.to_list(Map.get(reverse, start, MapSet.new())))
    do_bfs(reverse, queue, MapSet.new())
  end

  defp do_bfs(reverse, queue, visited) do
    case :queue.out(queue) do
      {:empty, _} ->
        visited

      {{:value, node}, rest} ->
        if MapSet.member?(visited, node) do
          do_bfs(reverse, rest, visited)
        else
          new_visited = MapSet.put(visited, node)
          neighbors = Map.get(reverse, node, MapSet.new())
          new_queue = enqueue_unvisited(neighbors, new_visited, rest)
          do_bfs(reverse, new_queue, new_visited)
        end
    end
  end

  defp enqueue_unvisited(neighbors, visited, queue) do
    Enum.reduce(neighbors, queue, fn neighbor, q ->
      if MapSet.member?(visited, neighbor), do: q, else: :queue.in(neighbor, q)
    end)
  end

  # Detect cycles using DFS with three-color marking
  defp detect_cycle(%__MODULE__{adjacency: adjacency}) do
    apps = Map.keys(adjacency)
    # :white = unvisited, :gray = in-progress, :black = done
    colors = Map.new(apps, fn app -> {app, :white} end)
    detect_cycle_dfs(apps, adjacency, colors, [])
  end

  defp detect_cycle_dfs([], _adjacency, _colors, _path), do: nil

  defp detect_cycle_dfs([app | rest], adjacency, colors, path) do
    case Map.get(colors, app) do
      :black ->
        detect_cycle_dfs(rest, adjacency, colors, path)

      :white ->
        case visit(app, adjacency, colors, [app]) do
          {:cycle, cycle} -> cycle
          {:ok, new_colors} -> detect_cycle_dfs(rest, adjacency, new_colors, path)
        end

      _ ->
        detect_cycle_dfs(rest, adjacency, colors, path)
    end
  end

  defp visit(app, adjacency, colors, path) do
    colors = Map.put(colors, app, :gray)
    deps = Map.get(adjacency, app, MapSet.new())

    result =
      Enum.reduce_while(deps, {:ok, colors}, fn dep, {:ok, acc_colors} ->
        visit_dep(dep, adjacency, acc_colors, path)
      end)

    case result do
      {:cycle, cycle} -> {:cycle, cycle}
      {:ok, final_colors} -> {:ok, Map.put(final_colors, app, :black)}
    end
  end

  defp visit_dep(dep, adjacency, colors, path) do
    case Map.get(colors, dep, :black) do
      :gray ->
        {:halt, {:cycle, extract_cycle(dep, path)}}

      :white ->
        case visit(dep, adjacency, colors, [dep | path]) do
          {:cycle, cycle} -> {:halt, {:cycle, cycle}}
          {:ok, new_colors} -> {:cont, {:ok, new_colors}}
        end

      :black ->
        {:cont, {:ok, colors}}
    end
  end

  defp extract_cycle(dep, reversed_path) do
    path = Enum.reverse(reversed_path)

    case Enum.find_index(path, &(&1 == dep)) do
      nil -> [dep | path]
      idx -> Enum.slice(path, idx..-1//1)
    end
  end
end
