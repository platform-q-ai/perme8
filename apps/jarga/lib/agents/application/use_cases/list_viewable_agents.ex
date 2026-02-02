defmodule Jarga.Agents.Application.UseCases.ListViewableAgents do
  @moduledoc """
  Use case for listing all agents viewable by a user.

  Returns:
  - User's own agents (PRIVATE + SHARED)
  - All other SHARED agents

  Used for agent view mode when accessed without workspace context.
  """

  @default_agent_repo Jarga.Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Lists all agents viewable by the user.

  ## Parameters
  - `user_id` - ID of the current user
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)

  ## Returns
  - List of agents the user can view
  """
  def execute(user_id, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    agent_repo.list_viewable_agents(user_id)
  end
end
