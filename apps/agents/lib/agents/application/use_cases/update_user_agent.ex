defmodule Agents.Application.UseCases.UpdateUserAgent do
  @moduledoc """
  Use case for updating a user-owned agent.

  Only the agent owner can update their agent.
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository
  @default_workspace_agent_repo Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  @default_notifier Agents.Infrastructure.Notifiers.PubSubNotifier

  @doc """
  Updates an agent if the user is the owner.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user
  - `attrs` - Map of attributes to update
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)
    - `:notifier` - Notifier module for PubSub events (default: PubSubNotifier)

  ## Returns
  - `{:ok, agent}` - Successfully updated agent
  - `{:error, :not_found}` - Agent not found or user not owner
  - `{:error, changeset}` - Validation error
  """
  def execute(agent_id, user_id, attrs, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    workspace_agent_repo = Keyword.get(opts, :workspace_agent_repo, @default_workspace_agent_repo)
    notifier = Keyword.get(opts, :notifier, @default_notifier)

    case agent_repo.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        case agent_repo.update_agent(agent, attrs) do
          {:ok, updated_agent} ->
            # Get all workspaces this agent is in
            workspace_ids = workspace_agent_repo.get_agent_workspace_ids(agent_id)

            # Notify all affected workspaces and user
            notifier.notify_agent_updated(updated_agent, workspace_ids)

            {:ok, updated_agent}

          error ->
            error
        end
    end
  end
end
