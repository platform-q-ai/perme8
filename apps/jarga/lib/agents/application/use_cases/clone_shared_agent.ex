defmodule Jarga.Agents.Application.UseCases.CloneSharedAgent do
  @moduledoc """
  Use case for cloning a shared agent to the user's personal library.

  Creates an independent copy with:
  - New owner (cloning user)
  - PRIVATE visibility by default
  - Name with " (Copy)" suffix
  - No workspace associations
  """

  alias Jarga.Agents.Domain.AgentCloner
  alias Jarga.Agents.Application.Policies.AgentPolicy

  @default_agent_repo Jarga.Agents.Infrastructure.Repositories.AgentRepository
  @default_workspace_agent_repo Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  @default_workspaces Jarga.Workspaces

  @doc """
  Clones a shared agent to the user's personal library.

  ## Parameters
  - `agent_id` - ID of the agent to clone
  - `user_id` - ID of the user cloning the agent
  - `opts` - Keyword list with:
    - `:workspace_id` - Optional workspace context for permission check
    - `:agent_repo` - Repository module for agents (default: AgentRepository)
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)
    - `:workspaces` - Workspaces context module (default: Jarga.Workspaces)

  ## Returns
  - `{:ok, agent}` - Successfully cloned agent
  - `{:error, :not_found}` - Agent not found
  - `{:error, :forbidden}` - User cannot clone this agent
  """
  def execute(agent_id, user_id, opts \\ []) do
    workspace_id = Keyword.get(opts, :workspace_id)
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    workspace_agent_repo = Keyword.get(opts, :workspace_agent_repo, @default_workspace_agent_repo)
    workspaces = Keyword.get(opts, :workspaces, @default_workspaces)

    case agent_repo.get(agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Check if user can clone this agent
        can_clone? =
          if workspace_id do
            # User must be a workspace member AND agent must be in that workspace
            user_is_member? = workspaces.member?(user_id, workspace_id)

            agent_in_workspace? =
              workspace_agent_repo.agent_in_workspace?(workspace_id, agent.id)

            user_is_member? and (agent.user_id == user_id or agent_in_workspace?)
          else
            # Without workspace context, only owner can clone
            agent.user_id == user_id
          end

        # Use domain policy to validate clone permission
        workspace_member? = workspace_id && workspaces.member?(user_id, workspace_id)

        if can_clone? and AgentPolicy.can_clone?(agent, user_id, workspace_member?) do
          clone_attrs = AgentCloner.clone_attrs(agent, user_id)
          agent_repo.create_agent(clone_attrs)
        else
          {:error, :forbidden}
        end
    end
  end
end
