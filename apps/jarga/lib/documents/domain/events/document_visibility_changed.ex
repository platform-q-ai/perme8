defmodule Jarga.Documents.Domain.Events.DocumentVisibilityChanged do
  @moduledoc """
  Domain event emitted when a document's visibility is changed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "document",
    fields: [document_id: nil, user_id: nil, is_public: nil],
    required: [:document_id, :workspace_id, :user_id, :is_public]
end
