defmodule EntityRelationshipManager.Application.UseCases.Traverse do
  @moduledoc """
  Use case for traversing the graph from a starting entity.

  Validates depth, direction, and limit via TraversalPolicy before
  delegating to the graph repository.
  """

  alias EntityRelationshipManager.Domain.Policies.{InputSanitizationPolicy, TraversalPolicy}

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Traverses the graph from the starting entity.

  Options:
  - `max_depth` - maximum traversal depth (default: TraversalPolicy.default_depth())
  - `direction` - "in", "out", or "both" (default: "both")
  - `limit` - max entities to return (validated by TraversalPolicy)

  Returns `{:ok, [entity]}` on success.
  """
  def execute(workspace_id, start_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)
    max_depth = Keyword.get(opts, :max_depth, TraversalPolicy.default_depth())
    direction = Keyword.get(opts, :direction, "both")

    with :ok <- InputSanitizationPolicy.validate_uuid(start_id),
         :ok <- TraversalPolicy.validate_depth(max_depth),
         :ok <- TraversalPolicy.validate_direction(direction),
         :ok <- validate_limit(opts) do
      traversal_opts =
        opts
        |> Keyword.put(:max_depth, max_depth)
        |> Keyword.put(:direction, direction)
        |> Keyword.delete(:graph_repo)

      graph_repo.traverse(workspace_id, start_id, traversal_opts)
    end
  end

  defp validate_limit(opts) do
    case Keyword.get(opts, :limit) do
      nil -> :ok
      limit -> TraversalPolicy.validate_limit(limit)
    end
  end
end
