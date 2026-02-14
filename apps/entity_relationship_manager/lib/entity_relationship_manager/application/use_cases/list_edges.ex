defmodule EntityRelationshipManager.Application.UseCases.ListEdges do
  @moduledoc """
  Use case for listing edges with optional filters.

  Validates filter parameters (type name, limit, offset) before delegating
  to the graph repository.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.{InputSanitizationPolicy, TraversalPolicy}

  @doc """
  Lists edges in a workspace with optional filters.

  Supported filters:
  - `type` - filter by edge type name
  - `limit` - max results
  - `offset` - pagination offset

  Returns `{:ok, [edge]}` on success.
  """
  def execute(workspace_id, filters, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())

    with :ok <- validate_filters(filters) do
      graph_repo.list_edges(workspace_id, filters)
    end
  end

  defp validate_filters(filters) do
    with :ok <- validate_type(filters),
         :ok <- validate_limit(filters) do
      validate_offset(filters)
    end
  end

  defp validate_type(%{type: type}), do: InputSanitizationPolicy.validate_type_name(type)
  defp validate_type(_), do: :ok

  defp validate_limit(%{limit: limit}), do: TraversalPolicy.validate_limit(limit)
  defp validate_limit(_), do: :ok

  defp validate_offset(%{offset: offset}), do: TraversalPolicy.validate_offset(offset)
  defp validate_offset(_), do: :ok
end
