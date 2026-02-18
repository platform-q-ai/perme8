defmodule EntityRelationshipManager.Domain.Events.EdgeCreated do
  @moduledoc """
  Domain event emitted when an edge is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "edge",
    fields: [edge_id: nil, user_id: nil, source_id: nil, target_id: nil, edge_type: nil],
    required: [:edge_id, :workspace_id, :source_id, :target_id, :edge_type]
end
