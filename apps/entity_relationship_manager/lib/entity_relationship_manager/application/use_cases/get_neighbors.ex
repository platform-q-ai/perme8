defmodule EntityRelationshipManager.Application.UseCases.GetNeighbors do
  @moduledoc """
  Use case for getting neighboring entities of a given entity.

  Validates parameters (direction, entity/edge type) via TraversalPolicy
  and InputSanitizationPolicy before delegating to the graph repository.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.{InputSanitizationPolicy, TraversalPolicy}

  @doc """
  Gets neighboring entities of the given entity.

  Options:
  - `direction` - "in", "out", or "both" (default: "both")
  - `entity_type` - filter neighbors by entity type
  - `edge_type` - filter by edge type

  Returns `{:ok, [entity]}` on success.
  """
  def execute(workspace_id, entity_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    direction = Keyword.get(opts, :direction, "both")

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id),
         :ok <- TraversalPolicy.validate_direction(direction),
         :ok <- validate_entity_type(opts),
         :ok <- validate_edge_type(opts) do
      traversal_opts =
        opts
        |> Keyword.put(:direction, direction)
        |> Keyword.delete(:graph_repo)
        |> Keyword.delete(:schema_repo)

      graph_repo.get_neighbors(workspace_id, entity_id, traversal_opts)
    end
  end

  defp validate_entity_type(opts) do
    case Keyword.get(opts, :entity_type) do
      nil -> :ok
      type -> InputSanitizationPolicy.validate_type_name(type)
    end
  end

  defp validate_edge_type(opts) do
    case Keyword.get(opts, :edge_type) do
      nil -> :ok
      type -> InputSanitizationPolicy.validate_type_name(type)
    end
  end
end
