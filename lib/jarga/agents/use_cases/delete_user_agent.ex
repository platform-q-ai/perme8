defmodule Jarga.Agents.UseCases.DeleteUserAgent do
  @moduledoc """
  Use case for deleting a user-owned agent.

  Only the agent owner can delete their agent.
  Cascade deletes all workspace_agents entries via database constraint.
  """

  alias Jarga.Agents.Infrastructure.AgentRepository
  alias Jarga.Agents.Infrastructure.WorkspaceAgentRepository
  alias Jarga.Agents.Infrastructure.Services.PubSubNotifier

  @doc """
  Deletes an agent if the user is the owner.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user

  ## Returns
  - `{:ok, agent}` - Successfully deleted agent
  - `{:error, :not_found}` - Agent not found or user not owner
  - `{:error, :forbidden}` - User is not the owner
  """
  def execute(agent_id, user_id) do
    case AgentRepository.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Get all workspaces this agent is in before deletion
        workspace_ids = WorkspaceAgentRepository.get_agent_workspace_ids(agent_id)

        case AgentRepository.delete_agent(agent) do
          {:ok, deleted_agent} ->
            # Notify all affected workspaces that the agent was deleted
            PubSubNotifier.notify_agent_deleted(deleted_agent, workspace_ids)

            {:ok, deleted_agent}

          error ->
            error
        end
    end
  end
end
