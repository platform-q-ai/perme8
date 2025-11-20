defmodule Jarga.Agents.UseCases.ListViewableAgents do
  @moduledoc """
  Use case for listing all agents viewable by a user.

  Returns:
  - User's own agents (PRIVATE + SHARED)
  - All other SHARED agents

  Used for agent view mode when accessed without workspace context.
  """

  alias Jarga.Agents.Infrastructure.AgentRepository

  @doc """
  Lists all agents viewable by the user.

  ## Parameters
  - `user_id` - ID of the current user

  ## Returns
  - List of agents the user can view
  """
  def execute(user_id) do
    AgentRepository.list_viewable_agents(user_id)
  end
end
