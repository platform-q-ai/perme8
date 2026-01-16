defmodule Jarga.Agents.Application.UseCases.ListUserAgents do
  @moduledoc """
  Use case for listing all agents owned by a user.

  Returns all agents (PRIVATE and SHARED) owned by the user.
  """

  alias Jarga.Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Lists all agents owned by a user.

  ## Parameters
  - `user_id` - ID of the user

  ## Returns
  - List of agents
  """
  def execute(user_id) do
    AgentRepository.list_agents_for_user(user_id)
  end
end
