defmodule EntityRelationshipManager.Application.UseCases.DeleteEdge do
  @moduledoc """
  Use case for soft-deleting an edge.

  Validates the UUID format then delegates to the graph repository.
  """

  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Soft-deletes an edge by ID.

  Returns `{:ok, edge}` on success.
  """
  def execute(workspace_id, edge_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)

    with :ok <- InputSanitizationPolicy.validate_uuid(edge_id) do
      graph_repo.soft_delete_edge(workspace_id, edge_id)
    end
  end
end
