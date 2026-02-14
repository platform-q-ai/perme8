defmodule EntityRelationshipManager.Application.UseCases.ListEntities do
  @moduledoc """
  Use case for listing entities with optional filters.

  Validates filter parameters (type name, limit, offset) before delegating
  to the graph repository.
  """

  alias EntityRelationshipManager.Domain.Policies.{InputSanitizationPolicy, TraversalPolicy}

  @graph_repo Application.compile_env(
                :entity_relationship_manager,
                :graph_repository,
                EntityRelationshipManager.Infrastructure.Repositories.GraphRepository
              )

  @doc """
  Lists entities in a workspace with optional filters.

  Supported filters:
  - `type` - filter by entity type name
  - `limit` - max results (validated by TraversalPolicy)
  - `offset` - pagination offset (validated by TraversalPolicy)

  Returns `{:ok, [entity]}` on success.
  """
  def execute(workspace_id, filters, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, @graph_repo)

    with :ok <- validate_filters(filters) do
      graph_repo.list_entities(workspace_id, filters)
    end
  end

  defp validate_filters(filters) do
    with :ok <- validate_type(filters),
         :ok <- validate_limit(filters),
         :ok <- validate_offset(filters) do
      :ok
    end
  end

  defp validate_type(%{type: type}), do: InputSanitizationPolicy.validate_type_name(type)
  defp validate_type(_), do: :ok

  defp validate_limit(%{limit: limit}), do: TraversalPolicy.validate_limit(limit)
  defp validate_limit(_), do: :ok

  defp validate_offset(%{offset: offset}), do: TraversalPolicy.validate_offset(offset)
  defp validate_offset(_), do: :ok
end
