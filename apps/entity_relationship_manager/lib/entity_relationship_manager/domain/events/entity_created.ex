defmodule EntityRelationshipManager.Domain.Events.EntityCreated do
  @moduledoc """
  Domain event emitted when an entity is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "entity",
    fields: [entity_id: nil, user_id: nil, entity_type: nil, properties: %{}],
    required: [:entity_id, :workspace_id, :entity_type]
end
