defmodule Jarga.Agents.Application.UseCases.ListUserAgents do
  @moduledoc """
  Use case for listing all agents owned by a user.

  Returns all agents (PRIVATE and SHARED) owned by the user.
  """

  @default_agent_repo Jarga.Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Lists all agents owned by a user.

  ## Parameters
  - `user_id` - ID of the user
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)

  ## Returns
  - List of agents
  """
  def execute(user_id, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    agent_repo.list_agents_for_user(user_id)
  end
end
