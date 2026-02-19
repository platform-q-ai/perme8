defmodule Agents.Application.UseCases.GetUserAgent do
  @moduledoc """
  Use case for getting a single user-owned agent by ID.

  Only the agent owner can retrieve the agent.
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Gets an agent if the user is the owner.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)

  ## Returns
  - `{:ok, agent}` - Agent found and owned by user
  - `{:error, :not_found}` - Agent not found or user not owner
  """
  def execute(agent_id, user_id, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)

    case agent_repo.get_agent_for_user(user_id, agent_id) do
      nil -> {:error, :not_found}
      agent -> {:ok, agent}
    end
  end
end
