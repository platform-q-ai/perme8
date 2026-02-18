defmodule EntityRelationshipManager.Domain.Events.SchemaUpdated do
  @moduledoc """
  Domain event emitted when a schema definition is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "schema",
    fields: [schema_id: nil, user_id: nil, changes: %{}],
    required: [:schema_id, :workspace_id]
end
