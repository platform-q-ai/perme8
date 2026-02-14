defmodule EntityRelationshipManager.Application.UseCases.GetSchema do
  @moduledoc """
  Use case for retrieving a workspace's schema definition.

  Delegates to the schema repository to fetch the schema.
  """

  @schema_repo Application.compile_env(
                 :entity_relationship_manager,
                 :schema_repository,
                 EntityRelationshipManager.Infrastructure.Repositories.SchemaRepository
               )

  @doc """
  Retrieves the schema definition for a workspace.

  Returns `{:ok, schema}` if found, `{:error, :not_found}` otherwise.
  """
  def execute(workspace_id, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, @schema_repo)
    schema_repo.get_schema(workspace_id)
  end
end
