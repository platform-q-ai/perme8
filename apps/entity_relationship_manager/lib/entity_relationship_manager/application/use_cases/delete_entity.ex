defmodule EntityRelationshipManager.Application.UseCases.DeleteEntity do
  @moduledoc """
  Use case for soft-deleting an entity.

  Validates the UUID format then delegates to the graph repository,
  which returns the deleted entity and the count of cascade-deleted edges.
  """

  alias EntityRelationshipManager.Application.RepoConfig
  alias EntityRelationshipManager.Domain.Events.EntityDeleted
  alias EntityRelationshipManager.Domain.Policies.InputSanitizationPolicy

  @default_event_bus Perme8.Events.EventBus

  @doc """
  Soft-deletes an entity by ID.

  Returns `{:ok, entity, deleted_edge_count}` on success.
  """
  def execute(workspace_id, entity_id, opts \\ []) do
    graph_repo = Keyword.get(opts, :graph_repo, RepoConfig.graph_repo())
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with :ok <- InputSanitizationPolicy.validate_uuid(entity_id),
         {:ok, deleted_entity, edge_count} <-
           graph_repo.soft_delete_entity(workspace_id, entity_id) do
      emit_entity_deleted_event(deleted_entity, workspace_id, event_bus)
      {:ok, deleted_entity, edge_count}
    end
  end

  # Part 2: thread actor_id from controller layer for audit trail attribution
  defp emit_entity_deleted_event(entity, workspace_id, event_bus) do
    event =
      EntityDeleted.new(%{
        aggregate_id: entity.id,
        actor_id: nil,
        entity_id: entity.id,
        workspace_id: workspace_id
      })

    event_bus.emit(event)
  end
end
