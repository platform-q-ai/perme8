defmodule Agents.Sessions.Domain.Events.SessionStateChanged do
  @moduledoc """
  Domain event emitted when a session lifecycle state changes.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil,
      from_state: nil,
      to_state: nil,
      lifecycle_state: nil,
      container_id: nil
    ],
    required: [:task_id, :from_state, :to_state]
end
