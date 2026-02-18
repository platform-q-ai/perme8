defmodule EntityRelationshipManager.Domain.Events.EntityDeleted do
  @moduledoc """
  Domain event emitted when an entity is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "entity",
    fields: [entity_id: nil, user_id: nil],
    required: [:entity_id, :workspace_id]
end
