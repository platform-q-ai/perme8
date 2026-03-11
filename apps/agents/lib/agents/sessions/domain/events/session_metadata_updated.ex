defmodule Agents.Sessions.Domain.Events.SessionMetadataUpdated do
  @moduledoc """
  Domain event emitted when session metadata is updated.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      title: nil,
      share_status: nil
    ],
    required: [:task_id]
end
