defmodule Identity.Domain.Events.WorkspaceUpdated do
  @moduledoc """
  Domain event emitted when a workspace is updated (e.g., renamed).

  Emitted by `Identity.Infrastructure.Notifiers.EmailAndPubSubNotifier.notify_workspace_updated/1`.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "workspace",
    fields: [name: nil],
    required: [:workspace_id]
end
