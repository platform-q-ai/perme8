defmodule Agents.Sessions.Domain.Events.SessionPaused do
  @moduledoc """
  Domain event emitted when a session is paused.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      session_id: nil,
      user_id: nil,
      paused_at: nil
    ],
    required: [:session_id, :user_id]
end
