defmodule EntityRelationshipManager.Application.UseCases.DeleteEntity do
  @moduledoc """
  Use case for soft-deleting an entity.

  Validates the UUID format then delegates to the graph repository,
  which returns the deleted entity and the count of cascade-deleted edges.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @doc """
  Soft-deletes an entity by ID.

  Returns `{:ok, entity, deleted_edge_count}` on success.
  """
  def execute(workspace_id, entity_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id) do
      graph_repo.soft_delete_entity(workspace_id, entity_id)
    end
  end
end
