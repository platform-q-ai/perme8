defmodule EntityRelationshipManager.Application.UseCases.GetEdge do
  @moduledoc """
  Use case for retrieving a single edge by ID.

  Validates the UUID format before delegating to the graph repository.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @doc """
  Retrieves an edge by workspace ID and edge ID.

  Returns `{:ok, edge}` if found, `{:error, :not_found}` otherwise.
  """
  def execute(workspace_id, edge_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())

    with :ok <- InputSanitizationPolicy.validate_uuid(edge_id) do
      graph_repo.get_edge(workspace_id, edge_id)
    end
  end
end
