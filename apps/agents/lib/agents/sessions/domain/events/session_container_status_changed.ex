defmodule Agents.Sessions.Domain.Events.SessionContainerStatusChanged do
  @moduledoc """
  Domain event emitted when a session's container status changes.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [
      session_id: nil,
      user_id: nil,
      from_status: nil,
      to_status: nil,
      container_id: nil
    ],
    required: [:session_id, :from_status, :to_status]
end
