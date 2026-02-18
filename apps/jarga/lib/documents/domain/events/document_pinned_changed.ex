defmodule Jarga.Documents.Domain.Events.DocumentPinnedChanged do
  @moduledoc """
  Domain event emitted when a document's pinned status is changed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "document",
    fields: [document_id: nil, user_id: nil, is_pinned: nil],
    required: [:document_id, :workspace_id, :user_id, :is_pinned]
end
