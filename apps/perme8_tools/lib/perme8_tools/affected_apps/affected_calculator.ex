defmodule Perme8Tools.AffectedApps.AffectedCalculator do
  @moduledoc """
  Computes the full set of affected apps from classified file changes
  and a dependency graph, including transitive dependency propagation.
  """

  alias Perme8Tools.AffectedApps.DependencyGraph

  @type result :: %{
          affected_apps: MapSet.t(atom()),
          all_apps?: boolean(),
          all_exo_bdd?: boolean()
        }

  @doc """
  Calculates the affected apps set from a file classification result and dependency graph.

  If `all_apps?` is true (shared config changed), returns all apps from the graph.
  Otherwise, computes the transitive closure of directly affected apps.

  The `all_exo_bdd?` flag is carried through to the result.
  """
  @spec calculate(map(), DependencyGraph.t()) :: result()
  def calculate(classification_result, %DependencyGraph{} = graph) do
    %{
      directly_affected: directly_affected,
      all_apps?: all_apps?,
      all_exo_bdd?: all_exo_bdd?
    } = classification_result

    affected_apps =
      if all_apps? do
        DependencyGraph.all_apps(graph)
      else
        Enum.reduce(directly_affected, MapSet.new(), fn app, acc ->
          acc
          |> MapSet.put(app)
          |> MapSet.union(DependencyGraph.transitive_dependents(graph, app))
        end)
      end

    %{
      affected_apps: affected_apps,
      all_apps?: all_apps?,
      all_exo_bdd?: all_exo_bdd?
    }
  end
end
