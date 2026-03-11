defmodule Agents.Sessions.Domain.Events.SessionCompacted do
  @moduledoc """
  Domain event emitted when a session has been compacted.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil
    ],
    required: [:task_id]
end
