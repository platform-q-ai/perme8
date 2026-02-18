defmodule EntityRelationshipManager.Domain.Events.SchemaCreated do
  @moduledoc """
  Domain event emitted when a schema definition is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "schema",
    fields: [schema_id: nil, user_id: nil, name: nil],
    required: [:schema_id, :workspace_id]
end
