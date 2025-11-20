defmodule Jarga.Agents.UseCases.CloneSharedAgent do
  @moduledoc """
  Use case for cloning a shared agent to the user's personal library.

  Creates an independent copy with:
  - New owner (cloning user)
  - PRIVATE visibility by default
  - Name with " (Copy)" suffix
  - No workspace associations
  """

  alias Jarga.Agents.Domain.AgentCloner
  alias Jarga.Agents.Policies.AgentPolicy
  alias Jarga.Repo
  alias Jarga.Agents.Infrastructure.Agent
  alias Jarga.Agents.Infrastructure.AgentRepository
  alias Jarga.Agents.Infrastructure.WorkspaceAgentRepository
  alias Jarga.Workspaces

  def execute(agent_id, user_id, opts \\ []) do
    workspace_id = Keyword.get(opts, :workspace_id)

    case AgentRepository.get(agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Check if user can clone this agent
        can_clone? =
          if workspace_id do
            # User must be a workspace member AND agent must be in that workspace
            user_is_member? = Workspaces.member?(user_id, workspace_id)

            agent_in_workspace? =
              WorkspaceAgentRepository.agent_in_workspace?(workspace_id, agent.id)

            user_is_member? and (agent.user_id == user_id or agent_in_workspace?)
          else
            # Without workspace context, only owner can clone
            agent.user_id == user_id
          end

        # Use domain policy to validate clone permission
        workspace_member? = workspace_id && Workspaces.member?(user_id, workspace_id)

        if can_clone? and AgentPolicy.can_clone?(agent, user_id, workspace_member?) do
          clone_attrs = AgentCloner.clone_attrs(agent, user_id)

          %Agent{}
          |> Agent.changeset(clone_attrs)
          |> Repo.insert()
        else
          {:error, :forbidden}
        end
    end
  end
end
