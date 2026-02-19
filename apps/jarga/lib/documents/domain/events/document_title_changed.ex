defmodule Jarga.Documents.Domain.Events.DocumentTitleChanged do
  @moduledoc """
  Domain event emitted when a document's title is changed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "document",
    fields: [document_id: nil, user_id: nil, title: nil, previous_title: nil],
    required: [:document_id, :workspace_id, :user_id, :title]
end
