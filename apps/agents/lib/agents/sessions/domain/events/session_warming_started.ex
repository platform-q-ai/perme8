defmodule Agents.Sessions.Domain.Events.SessionWarmingStarted do
  @moduledoc """
  Domain event emitted when session warming begins.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "session",
    fields: [task_id: nil, user_id: nil, container_id: nil],
    required: [:task_id]
end
