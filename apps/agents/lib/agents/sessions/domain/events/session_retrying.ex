defmodule Agents.Sessions.Domain.Events.SessionRetrying do
  @moduledoc """
  Domain event emitted when a session reports retry metadata.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      attempt: 0,
      message: nil,
      next_at: nil
    ],
    required: [:task_id, :attempt]
end
