defmodule Jarga.Agents.UseCases.RemoveAgentFromWorkspace do
  @moduledoc """
  Use case for removing an agent from a workspace.

  Deletes the workspace_agents join table entry.
  Agent persists in user's library.
  Only the agent owner can remove their agent from workspaces.
  """

  @doc """
  Removes an agent from a workspace.

  ## Parameters
  - `agent_id` - ID of the agent to remove
  - `workspace_id` - ID of the workspace
  - `user_id` - ID of the user performing the action
  - `opts` - Keyword list with:
    - `:agent_repo` - Function to get agent
    - `:workspace_agent_repo` - Function to delete workspace_agent entry

  ## Returns
  - `{:ok, :deleted}` - Successfully removed (or didn't exist)
  - `{:error, :not_found}` - Agent not found
  - `{:error, :forbidden}` - User doesn't own agent
  """
  def execute(agent_id, workspace_id, user_id, opts) do
    agent_repo = Keyword.fetch!(opts, :agent_repo)
    workspace_agent_repo = Keyword.fetch!(opts, :workspace_agent_repo)

    with {:ok, agent} <- agent_repo.(agent_id),
         :ok <- validate_ownership(agent, user_id) do
      workspace_agent_repo.(workspace_id, agent_id)
    end
  end

  defp validate_ownership(%{user_id: owner_id}, user_id) when owner_id == user_id, do: :ok
  defp validate_ownership(_agent, _user_id), do: {:error, :forbidden}
end
