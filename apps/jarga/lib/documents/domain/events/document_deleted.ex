defmodule Jarga.Documents.Domain.Events.DocumentDeleted do
  @moduledoc """
  Domain event emitted when a document is deleted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "document",
    fields: [document_id: nil, user_id: nil],
    required: [:document_id, :workspace_id, :user_id]
end
