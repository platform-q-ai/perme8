defmodule Jarga.Agents.UseCases.UpdateUserAgent do
  @moduledoc """
  Use case for updating a user-owned agent.

  Only the agent owner can update their agent.
  """

  alias Jarga.Agents.Infrastructure.AgentRepository
  alias Jarga.Agents.Infrastructure.WorkspaceAgentRepository
  alias Jarga.Agents.Infrastructure.Services.PubSubNotifier

  @doc """
  Updates an agent if the user is the owner.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user
  - `attrs` - Map of attributes to update

  ## Returns
  - `{:ok, agent}` - Successfully updated agent
  - `{:error, :not_found}` - Agent not found or user not owner
  - `{:error, changeset}` - Validation error
  """
  def execute(agent_id, user_id, attrs) do
    case AgentRepository.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        case AgentRepository.update_agent(agent, attrs) do
          {:ok, updated_agent} ->
            # Get all workspaces this agent is in
            workspace_ids = WorkspaceAgentRepository.get_agent_workspace_ids(agent_id)

            # Notify all affected workspaces and user
            PubSubNotifier.notify_agent_updated(updated_agent, workspace_ids)

            {:ok, updated_agent}

          error ->
            error
        end
    end
  end
end
