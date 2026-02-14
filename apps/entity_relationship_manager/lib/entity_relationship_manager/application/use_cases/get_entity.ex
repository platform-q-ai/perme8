defmodule EntityRelationshipManager.Application.UseCases.GetEntity do
  @moduledoc """
  Use case for retrieving a single entity by ID.

  Validates the UUID format before delegating to the graph repository.
  """

  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Retrieves an entity by workspace ID and entity ID.

  Returns `{:ok, entity}` if found, `{:error, :not_found}` otherwise.
  """
  def execute(workspace_id, entity_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id) do
      graph_repo.get_entity(workspace_id, entity_id)
    end
  end
end
