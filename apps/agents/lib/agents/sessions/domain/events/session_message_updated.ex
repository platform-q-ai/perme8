defmodule Agents.Sessions.Domain.Events.SessionMessageUpdated do
  @moduledoc """
  Domain event emitted when session message tracking fields change.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      message_count: 0,
      streaming_active: false,
      active_tool_calls: 0
    ],
    required: [:task_id]
end
