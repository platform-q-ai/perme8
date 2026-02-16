defmodule Agents.Application.UseCases.SyncAgentWorkspaces do
  @moduledoc """
  Use case for synchronizing an agent's workspace associations.

  Only the agent owner can sync workspaces, and they can only add the agent
  to workspaces they belong to.
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository
  @default_workspace_agent_repo Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  @default_notifier Agents.Infrastructure.Notifiers.PubSubNotifier
  @default_accounts Jarga.Accounts
  @default_workspaces Jarga.Workspaces

  @doc """
  Synchronizes workspace associations for an agent.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user (must be agent owner)
  - `workspace_ids` - List of workspace IDs to associate with the agent
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)
    - `:notifier` - Notifier module for PubSub events (default: PubSubNotifier)
    - `:accounts` - Accounts context module (default: Jarga.Accounts)
    - `:workspaces` - Workspaces context module (default: Jarga.Workspaces)

  ## Returns
  - `:ok` - Successfully synchronized
  - `{:error, :not_found}` - Agent not found or user not owner

  ## Behavior
  - Adds agent to new workspaces (only if user belongs to them)
  - Removes agent from workspaces no longer in the list
  - All operations performed atomically in a transaction
  """
  def execute(agent_id, user_id, workspace_ids, opts \\ []) do
    agent_repo = Keyword.get(opts, :agent_repo, @default_agent_repo)
    workspace_agent_repo = Keyword.get(opts, :workspace_agent_repo, @default_workspace_agent_repo)
    notifier = Keyword.get(opts, :notifier, @default_notifier)
    accounts = Keyword.get(opts, :accounts, @default_accounts)
    workspaces = Keyword.get(opts, :workspaces, @default_workspaces)

    # Verify agent exists and belongs to user
    case agent_repo.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Calculate workspace changes
        changes =
          calculate_workspace_changes(
            agent_id,
            user_id,
            workspace_ids,
            workspace_agent_repo,
            accounts,
            workspaces
          )

        # Apply changes atomically
        apply_workspace_changes(agent_id, changes, workspace_agent_repo)

        # Notify all affected workspaces
        notifier.notify_workspace_associations_changed(
          agent,
          MapSet.to_list(changes.to_add),
          MapSet.to_list(changes.to_remove)
        )

        :ok
    end
  end

  # Calculate what workspaces to add and remove
  defp calculate_workspace_changes(
         agent_id,
         user_id,
         workspace_ids,
         workspace_agent_repo,
         accounts,
         workspaces
       ) do
    current_workspace_ids = workspace_agent_repo.get_agent_workspace_ids(agent_id)
    desired_workspace_ids = workspace_ids |> List.wrap() |> MapSet.new()
    current_workspace_ids_set = MapSet.new(current_workspace_ids)

    to_add = MapSet.difference(desired_workspace_ids, current_workspace_ids_set)
    to_remove = MapSet.difference(current_workspace_ids_set, desired_workspace_ids)

    # Get user's workspaces to validate membership
    user = accounts.get_user!(user_id)
    user_workspaces = workspaces.list_workspaces_for_user(user)
    user_workspace_ids = MapSet.new(Enum.map(user_workspaces, & &1.id))

    # Filter to_add to only include workspaces user belongs to
    valid_to_add = MapSet.intersection(to_add, user_workspace_ids)

    %{to_add: valid_to_add, to_remove: to_remove}
  end

  # Apply workspace changes in a transaction
  defp apply_workspace_changes(
         agent_id,
         %{to_add: to_add, to_remove: to_remove},
         workspace_agent_repo
       ) do
    workspace_agent_repo.sync_agent_workspaces(agent_id, to_add, to_remove)
  end
end
