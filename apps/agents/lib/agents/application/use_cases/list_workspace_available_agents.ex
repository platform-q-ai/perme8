defmodule Agents.Application.UseCases.ListWorkspaceAvailableAgents do
  @moduledoc """
  Use case for listing agents available in a workspace for the current user.

  Returns:
  - my_agents: User's own agents (PRIVATE + SHARED) in the workspace
  - other_agents: Other users' SHARED agents in the workspace
  """

  @default_workspace_agent_repo Agents.Infrastructure.Repositories.WorkspaceAgentRepository

  @doc """
  Lists all agents available in a workspace for the current user.

  ## Parameters
  - `workspace_id` - ID of the workspace
  - `user_id` - ID of the current user
  - `opts` - Keyword list with:
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)

  ## Returns
  - Map with `:my_agents` and `:other_agents` lists
  """
  def execute(workspace_id, user_id, opts \\ []) do
    workspace_agent_repo = Keyword.get(opts, :workspace_agent_repo, @default_workspace_agent_repo)
    workspace_agent_repo.list_workspace_agents(workspace_id, user_id)
  end
end
