defmodule Agents.Application.UseCases.AddAgentToWorkspace do
  @moduledoc """
  Use case for adding an agent to a workspace.

  Creates a workspace_agents join table entry.
  Only the agent owner can add their agent to workspaces they belong to.
  """

  @doc """
  Adds an agent to a workspace.

  ## Parameters
  - `agent_id` - ID of the agent to add
  - `workspace_id` - ID of the workspace
  - `user_id` - ID of the user performing the action
  - `opts` - Keyword list with:
    - `:agent_repo` - Function to get agent (default: raises)
    - `:workspace_member_check` - Function to check workspace membership
    - `:workspace_agent_repo` - Function to create workspace_agent entry

  ## Returns
  - `{:ok, workspace_agent}` - Successfully added
  - `{:error, :not_found}` - Agent not found
  - `{:error, :forbidden}` - User doesn't own agent or isn't workspace member
  - `{:error, :already_exists}` - Agent already in workspace
  """
  def execute(agent_id, workspace_id, user_id, opts) do
    agent_repo = Keyword.fetch!(opts, :agent_repo)
    workspace_member_check = Keyword.fetch!(opts, :workspace_member_check)
    workspace_agent_repo = Keyword.fetch!(opts, :workspace_agent_repo)

    with {:ok, agent} <- agent_repo.(agent_id),
         :ok <- validate_ownership(agent, user_id),
         :ok <- validate_workspace_membership(workspace_id, user_id, workspace_member_check) do
      workspace_agent_repo.(workspace_id, agent_id)
    end
  end

  defp validate_ownership(%{user_id: owner_id}, user_id) when owner_id == user_id, do: :ok
  defp validate_ownership(_agent, _user_id), do: {:error, :forbidden}

  defp validate_workspace_membership(workspace_id, user_id, check_fn) do
    if check_fn.(workspace_id, user_id) do
      :ok
    else
      {:error, :forbidden}
    end
  end
end
