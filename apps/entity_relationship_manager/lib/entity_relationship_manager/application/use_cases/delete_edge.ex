defmodule EntityRelationshipManager.Application.UseCases.DeleteEdge do
  @moduledoc """
  Use case for soft-deleting an edge.

  Validates the UUID format then delegates to the graph repository.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Events.EdgeDeleted
  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @default_event_bus Perme8.Events.EventBus

  @doc """
  Soft-deletes an edge by ID.

  Returns `{:ok, edge}` on success.
  """
  def execute(workspace_id, edge_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with :ok <- InputSanitizationPolicy.validate_uuid(edge_id),
         {:ok, deleted_edge} <- graph_repo.soft_delete_edge(workspace_id, edge_id) do
      emit_edge_deleted_event(deleted_edge, workspace_id, event_bus)
      {:ok, deleted_edge}
    end
  end

  defp emit_edge_deleted_event(edge, workspace_id, event_bus) do
    event =
      EdgeDeleted.new(%{
        aggregate_id: edge.id,
        actor_id: nil,
        edge_id: edge.id,
        workspace_id: workspace_id
      })

    event_bus.emit(event)
  end
end
