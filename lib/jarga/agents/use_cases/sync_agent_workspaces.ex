defmodule Jarga.Agents.UseCases.SyncAgentWorkspaces do
  @moduledoc """
  Use case for synchronizing an agent's workspace associations.

  Only the agent owner can sync workspaces, and they can only add the agent
  to workspaces they belong to.
  """

  alias Jarga.Accounts
  alias Jarga.Workspaces
  alias Jarga.Agents.Infrastructure.AgentRepository
  alias Jarga.Agents.Infrastructure.WorkspaceAgentRepository
  alias Jarga.Agents.Infrastructure.Services.PubSubNotifier

  @doc """
  Synchronizes workspace associations for an agent.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user (must be agent owner)
  - `workspace_ids` - List of workspace IDs to associate with the agent

  ## Returns
  - `:ok` - Successfully synchronized
  - `{:error, :not_found}` - Agent not found or user not owner

  ## Behavior
  - Adds agent to new workspaces (only if user belongs to them)
  - Removes agent from workspaces no longer in the list
  - All operations performed atomically in a transaction
  """
  def execute(agent_id, user_id, workspace_ids) do
    # Verify agent exists and belongs to user
    case AgentRepository.get_agent_for_user(user_id, agent_id) do
      nil ->
        {:error, :not_found}

      agent ->
        # Calculate workspace changes
        changes = calculate_workspace_changes(agent_id, user_id, workspace_ids)

        # Apply changes atomically
        apply_workspace_changes(agent_id, changes)

        # Notify all affected workspaces
        PubSubNotifier.notify_workspace_associations_changed(
          agent,
          MapSet.to_list(changes.to_add),
          MapSet.to_list(changes.to_remove)
        )

        :ok
    end
  end

  # Calculate what workspaces to add and remove
  defp calculate_workspace_changes(agent_id, user_id, workspace_ids) do
    current_workspace_ids = WorkspaceAgentRepository.get_agent_workspace_ids(agent_id)
    desired_workspace_ids = workspace_ids |> List.wrap() |> MapSet.new()
    current_workspace_ids_set = MapSet.new(current_workspace_ids)

    to_add = MapSet.difference(desired_workspace_ids, current_workspace_ids_set)
    to_remove = MapSet.difference(current_workspace_ids_set, desired_workspace_ids)

    # Get user's workspaces to validate membership
    user = Accounts.get_user!(user_id)
    user_workspaces = Workspaces.list_workspaces_for_user(user)
    user_workspace_ids = MapSet.new(Enum.map(user_workspaces, & &1.id))

    # Filter to_add to only include workspaces user belongs to
    valid_to_add = MapSet.intersection(to_add, user_workspace_ids)

    %{to_add: valid_to_add, to_remove: to_remove}
  end

  # Apply workspace changes in a transaction
  defp apply_workspace_changes(agent_id, %{to_add: to_add, to_remove: to_remove}) do
    Jarga.Repo.transaction(fn ->
      add_to_workspaces(agent_id, to_add)
      remove_from_workspaces(agent_id, to_remove)
    end)
  end

  defp add_to_workspaces(agent_id, workspace_ids) do
    Enum.each(workspace_ids, fn workspace_id ->
      WorkspaceAgentRepository.add_to_workspace(workspace_id, agent_id)
    end)
  end

  defp remove_from_workspaces(agent_id, workspace_ids) do
    Enum.each(workspace_ids, fn workspace_id ->
      WorkspaceAgentRepository.remove_from_workspace(workspace_id, agent_id)
    end)
  end
end
