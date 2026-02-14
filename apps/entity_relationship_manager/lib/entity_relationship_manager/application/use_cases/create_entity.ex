defmodule EntityRelationshipManager.Application.UseCases.CreateEntity do
  @moduledoc """
  Use case for creating an entity in the graph.

  Fetches the workspace schema, validates the entity type exists,
  validates properties against the schema, sanitizes the type name,
  then creates via the graph repository.
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
  Creates an entity in the workspace graph.

  Attrs should contain:
  - `type` - entity type name (must exist in schema)
  - `properties` - map of property values

  Returns `{:ok, entity}` on success, `{:error, reason}` on failure.
  """
  def execute(workspace_id, attrs, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, @schema_repo)
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)

    type = Map.get(attrs, :type)
    properties = Map.get(attrs, :properties, %{})

    with :ok <- InputSanitizationPolicy.validate_type_name(type),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id),
         :ok <- validate_entity(schema, type, properties) do
      graph_repo.create_entity(workspace_id, type, properties)
    end
  end

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_entity(schema, type, properties) do
    entity = Entity.new(%{type: type, properties: properties})
    SchemaValidationPolicy.validate_entity_against_schema(entity, schema, type)
  end
end
