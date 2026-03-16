defmodule Agents.Sessions.Domain.Events.SessionResumed do
  @moduledoc """
  Domain event emitted when a session is resumed.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      session_id: nil,
      user_id: nil,
      resumed_at: nil
    ],
    required: [:session_id, :user_id]
end
