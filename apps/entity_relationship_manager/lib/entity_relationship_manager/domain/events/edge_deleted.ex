defmodule EntityRelationshipManager.Domain.Events.EdgeDeleted do
  @moduledoc """
  Domain event emitted when an edge is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "edge",
    fields: [edge_id: nil, user_id: nil],
    required: [:edge_id, :workspace_id]
end
