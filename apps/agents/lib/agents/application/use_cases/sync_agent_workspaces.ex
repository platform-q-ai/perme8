defmodule Agents.Application.UseCases.SyncAgentWorkspaces do
  @moduledoc """
  Use case for synchronizing an agent's workspace associations.

  Only the agent owner can sync workspaces, and they can only add the agent
  to workspaces they belong to.
  """

  @default_agent_repo Agents.Infrastructure.Repositories.AgentRepository
  @default_workspace_agent_repo Agents.Infrastructure.Repositories.WorkspaceAgentRepository
  @default_event_bus Perme8.Events.EventBus
  @default_accounts Jarga.Accounts
  @default_workspaces Jarga.Workspaces

  alias Agents.Domain.Events.AgentAddedToWorkspace
  alias Agents.Domain.Events.AgentRemovedFromWorkspace

  @doc """
  Synchronizes workspace associations for an agent.

  ## Parameters
  - `agent_id` - ID of the agent
  - `user_id` - ID of the current user (must be agent owner)
  - `workspace_ids` - List of workspace IDs to associate with the agent
  - `opts` - Keyword list with:
    - `:agent_repo` - Repository module for agents (default: AgentRepository)
    - `:workspace_agent_repo` - Repository for workspace-agent associations (default: WorkspaceAgentRepository)
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
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
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

        # Emit domain events for workspace changes
        emit_workspace_change_events(agent_id, user_id, changes, event_bus)

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

  # Emit domain events for workspace add/remove
  defp emit_workspace_change_events(agent_id, user_id, changes, event_bus) do
    added_events =
      changes.to_add
      |> MapSet.to_list()
      |> Enum.map(fn ws_id ->
        AgentAddedToWorkspace.new(%{
          aggregate_id: agent_id,
          actor_id: user_id,
          agent_id: agent_id,
          workspace_id: ws_id,
          user_id: user_id
        })
      end)

    removed_events =
      changes.to_remove
      |> MapSet.to_list()
      |> Enum.map(fn ws_id ->
        AgentRemovedFromWorkspace.new(%{
          aggregate_id: agent_id,
          actor_id: user_id,
          agent_id: agent_id,
          workspace_id: ws_id,
          user_id: user_id
        })
      end)

    event_bus.emit_all(added_events ++ removed_events)
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
