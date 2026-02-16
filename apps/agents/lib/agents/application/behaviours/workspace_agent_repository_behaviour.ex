defmodule Agents.Application.Behaviours.WorkspaceAgentRepositoryBehaviour do
  @moduledoc """
  Behaviour defining the workspace-agent association repository contract.
  """

  @type agent_id :: Ecto.UUID.t()
  @type workspace_id :: Ecto.UUID.t()
  @type user_id :: Ecto.UUID.t()

  @callback get_agent_workspace_ids(agent_id) :: [workspace_id]
  @callback agent_in_workspace?(workspace_id, agent_id) :: boolean()
  @callback add_to_workspace(workspace_id, agent_id) ::
              {:ok, struct()} | {:error, Ecto.Changeset.t()}
  @callback remove_from_workspace(workspace_id, agent_id) :: :ok
  @callback list_workspace_agents(workspace_id, user_id) :: %{
              my_agents: [struct()],
              other_agents: [struct()]
            }
  @callback sync_agent_workspaces(agent_id, MapSet.t(), MapSet.t()) ::
              {:ok, :synced} | {:error, any()}
end
