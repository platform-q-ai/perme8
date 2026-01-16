defmodule Jarga.Agents.Application.UseCases.ListWorkspaceAvailableAgents do
  @moduledoc """
  Use case for listing agents available in a workspace for the current user.

  Returns:
  - my_agents: User's own agents (PRIVATE + SHARED) in the workspace
  - other_agents: Other users' SHARED agents in the workspace
  """

  alias Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  @doc """
  Lists all agents available in a workspace for the current user.

  ## Parameters
  - `workspace_id` - ID of the workspace
  - `user_id` - ID of the current user

  ## Returns
  - Map with `:my_agents` and `:other_agents` lists
  """
  def execute(workspace_id, user_id) do
    WorkspaceAgentRepository.list_workspace_agents(workspace_id, user_id)
  end
end
