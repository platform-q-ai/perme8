defmodule EntityRelationshipManager.Application.UseCases.GetEntity do
  @moduledoc """
  Use case for retrieving a single entity by ID.

  Validates the UUID format before delegating to the graph repository.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @doc """
  Retrieves an entity by workspace ID and entity ID.

  Returns `{:ok, entity}` if found, `{:error, :not_found}` otherwise.
  """
  def execute(workspace_id, entity_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())

    include_deleted = Keyword.get(opts, :include_deleted, false)

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id) do
      graph_repo.get_entity(workspace_id, entity_id, include_deleted: include_deleted)
    end
  end
end
