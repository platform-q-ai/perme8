defmodule EntityRelationshipManager.Application.UseCases.FindPaths do
  @moduledoc """
  Use case for finding paths between two entities.

  Validates depth via TraversalPolicy and UUIDs via InputSanitizationPolicy
  before delegating to the graph repository.
  """

  alias EntityRelationshipManager.Domain.Policies.{InputSanitizationPolicy, TraversalPolicy}

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Finds paths between source and target entities.

  Options:
  - `max_depth` - maximum path depth (default: TraversalPolicy.default_depth())

  Returns `{:ok, [path]}` where each path is a list of entities.
  """
  def execute(workspace_id, source_id, target_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)
    max_depth = Keyword.get(opts, :max_depth, TraversalPolicy.default_depth())

    with :ok <- InputSanitizationPolicy.validate_uuid(source_id),
         :ok <- InputSanitizationPolicy.validate_uuid(target_id),
         :ok <- TraversalPolicy.validate_depth(max_depth) do
      traversal_opts =
        opts
        |> Keyword.put(:max_depth, max_depth)
        |> Keyword.delete(:graph_repo)

      graph_repo.find_paths(workspace_id, source_id, target_id, traversal_opts)
    end
  end
end
