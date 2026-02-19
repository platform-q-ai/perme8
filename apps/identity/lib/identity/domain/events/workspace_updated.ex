defmodule Identity.Domain.Events.WorkspaceUpdated do
  @moduledoc """
  Domain event emitted when a workspace is updated (e.g., renamed).

  Emitted by `Identity.update_workspace/4` when a workspace is renamed or modified.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace",
    fields: [name: nil],
    required: [:workspace_id]
end
