defmodule EntityRelationshipManager.Domain.Events.EntityUpdated do
  @moduledoc """
  Domain event emitted when an entity is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "entity",
    fields: [entity_id: nil, user_id: nil, changes: %{}],
    required: [:entity_id, :workspace_id]
end
