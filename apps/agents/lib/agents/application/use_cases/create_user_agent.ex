defmodule Agents.Application.UseCases.CreateUserAgent do
  @moduledoc """
  Use case for creating a user-owned agent.

  Creates an agent with:
  - Required user_id (owner)
  - Default visibility: PRIVATE
  - No workspace associations by default
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository

  @doc """
  Creates a new agent owned by the specified user.

  ## Parameters
  - `attrs` - Map of agent attributes including user_id
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)

  ## Returns
  - `{:ok, agent}` - Successfully created agent
  - `{:error, changeset}` - Validation error
  """
  def execute(attrs, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    agent_repo.create_agent(attrs)
  end
end
