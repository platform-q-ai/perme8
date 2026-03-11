defmodule Agents.Sessions.Domain.Events.SessionServerConnected do
  @moduledoc """
  Domain event emitted when a session server connection is established.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      task_id: nil,
      user_id: nil
    ],
    required: [:task_id]
end
