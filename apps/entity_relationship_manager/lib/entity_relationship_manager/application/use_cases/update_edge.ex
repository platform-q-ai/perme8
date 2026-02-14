defmodule EntityRelationshipManager.Application.UseCases.UpdateEdge do
  @moduledoc """
  Use case for updating an edge's properties.

  Fetches the schema, retrieves the existing edge, validates the new
  properties against the schema, then updates via the graph repository.
  """

  alias EntityRelationshipManager.Domain.Entities.Edge

  alias EntityRelationshipManager.Application.RepoConfig

  alias EntityRelationshipManager.Domain.Policies.{
    SchemaValidationPolicy,
    InputSanitizationPolicy
  }

  @doc """
  Updates an edge's properties.

  Returns `{:ok, edge}` on success, `{:error, reason}` on failure.
  """
  def execute(workspace_id, edge_id, properties, opts \\ []) do
    schema_repo = Keyword.get(opts, :schema_repo, RepoConfig.schema_repo())
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())

    with :ok <- InputSanitizationPolicy.validate_uuid(edge_id),
         {:ok, schema} <- fetch_schema(schema_repo, workspace_id),
         {:ok, existing} <- graph_repo.get_edge(workspace_id, edge_id),
         :ok <- validate_properties(schema, existing.type, properties) do
      graph_repo.update_edge(workspace_id, edge_id, properties)
    end
  end

  defp fetch_schema(schema_repo, workspace_id) do
    case schema_repo.get_schema(workspace_id) do
      {:ok, schema} -> {:ok, schema}
      {:error, :not_found} -> {:error, :schema_not_found}
    end
  end

  defp validate_properties(schema, type, properties) do
    edge = Edge.new(%{type: type, properties: properties})
    SchemaValidationPolicy.validate_edge_against_schema(edge, schema, type)
  end
end
