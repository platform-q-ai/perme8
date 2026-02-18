defmodule Jarga.Documents.Domain.Events.DocumentCreated do
  @moduledoc """
  Domain event emitted when a document is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "document",
    fields: [document_id: nil, project_id: nil, user_id: nil, title: nil],
    required: [:document_id, :workspace_id, :project_id, :user_id, :title]
end
