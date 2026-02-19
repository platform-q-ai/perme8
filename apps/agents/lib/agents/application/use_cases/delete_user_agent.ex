defmodule Agents.Application.UseCases.DeleteUserAgent do
  @moduledoc """
  Use case for deleting a user-owned agent.

  Only the agent owner can delete their agent.
  Cascade deletes all workspace_agents entries via database constraint.
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository
  @default_workspace_agent_repo Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  @default_event_bus Perme8.Events.EventBus

  alias Agents.Domain.Events.AgentDeleted

  @doc """
  Deletes an agent if the user is the owner.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)
  ## Returns
  - `{:ok, agent}` - Successfully deleted agent
  - `{:error, :not_found}` - Agent not found or user not owner
  - `{:error, :forbidden}` - User is not the owner
  """
  def execute(agent_id, user_id, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    workspace_agent_repo = Keyword.get(opts, :workspace_agent_repo, @default_workspace_agent_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    case agent_repo.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Get all workspaces this agent is in before deletion
        workspace_ids = workspace_agent_repo.get_agent_workspace_ids(agent_id)

        case agent_repo.delete_agent(agent) do
          {:ok, deleted_agent} ->
            # Emit domain event
            emit_agent_deleted_event(agent_id, user_id, workspace_ids, event_bus)

            {:ok, deleted_agent}

          error ->
            error
        end
    end
  end

  defp emit_agent_deleted_event(agent_id, user_id, workspace_ids, event_bus) do
    event =
      AgentDeleted.new(%{
        aggregate_id: agent_id,
        actor_id: user_id,
        agent_id: agent_id,
        user_id: user_id,
        workspace_ids: workspace_ids
      })

    event_bus.emit(event)
  end
end
