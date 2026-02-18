defmodule Agents.Domain.Events.AgentCreated do
  @moduledoc """
  Domain event emitted when an agent is created.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "agent",
    fields: [agent_id: nil, user_id: nil, name: nil],
    required: [:agent_id, :user_id, :name]
end
