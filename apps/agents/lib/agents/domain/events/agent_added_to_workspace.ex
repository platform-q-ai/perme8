defmodule Agents.Domain.Events.AgentAddedToWorkspace do
  @moduledoc """
  Domain event emitted when an agent is added to a workspace.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "agent",
    fields: [agent_id: nil, user_id: nil],
    required: [:agent_id, :workspace_id, :user_id]
end
