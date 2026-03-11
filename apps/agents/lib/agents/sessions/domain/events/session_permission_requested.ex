defmodule Agents.Sessions.Domain.Events.SessionPermissionRequested do
  @moduledoc """
  Domain event emitted when a session requests user permission.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      tool_name: nil,
      action_description: nil,
      permission_id: nil
    ],
    required: [:task_id, :permission_id]
end
