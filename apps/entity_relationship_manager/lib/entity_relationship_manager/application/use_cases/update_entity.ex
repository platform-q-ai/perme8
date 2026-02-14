defmodule EntityRelationshipManager.Application.UseCases.UpdateEntity do
  @moduledoc """
  Use case for updating an entity's properties.

  Fetches the schema, retrieves the existing entity, validates the new
  properties against the schema, then updates via the graph repository.
  """

  alias EntityRelationshipManager.Domain.Entities.Entity

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @schema_repo Application.compile_env(
                 :entity_relationship_manager,
                 :schema_repository,
                 EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
               )

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Updates an entity's properties.

  Returns `{:ok, entity}` on success, `{:error, reason}` on failure.
  """
  def execute(workspace_id, entity_id, properties, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, @schema_repo)
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id),
         {:ok, existing} <- graph_repo.get_entity(workspace_id, entity_id),
         :ok <- validate_properties(schema, existing.type, properties) do
      graph_repo.update_entity(workspace_id, entity_id, properties)
    end
  end

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_properties(schema, type, properties) do
    entity = Entity.new(%{type: type, properties: properties})
    SchemaValidationPolicy.validate_entity_against_schema(entity, schema, type)
  end
end
