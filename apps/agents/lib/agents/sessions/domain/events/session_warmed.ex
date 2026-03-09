defmodule Agents.Sessions.Domain.Events.SessionWarmed do
  @moduledoc """
  Domain event emitted when a warmed container is ready.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [task_id: nil, user_id: nil, container_id: nil, container_port: nil],
    required: [:task_id]
end
