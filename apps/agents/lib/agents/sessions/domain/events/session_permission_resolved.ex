defmodule Agents.Sessions.Domain.Events.SessionPermissionResolved do
  @moduledoc """
  Domain event emitted when a session permission request is resolved.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      permission_id: nil,
      outcome: nil
    ],
    required: [:task_id, :permission_id, :outcome]
end
