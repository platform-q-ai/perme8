defmodule Jarga.Agents.Infrastructure.Repositories.WorkspaceAgentRepository do
  @moduledoc """
  Repository for managing workspace-agent associations.

  Handles the many-to-many relationship between agents and workspaces.
  """

  @behaviour Jarga.Agents.Application.Behaviours.WorkspaceAgentRepositoryBehaviour

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Agents.Infrastructure.Schemas.AgentSchema
  alias Jarga.Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema

  @doc """
  Adds an agent to a workspace.

  Creates a workspace_agents join table entry.

  ## Examples

      iex> add_to_workspace(workspace_id, agent_id)
      {:ok, %WorkspaceAgentJoin{}}

      iex> add_to_workspace(workspace_id, already_added_agent_id)
      {:error, %Ecto.Changeset{}}
  """
  @impl true
  @spec add_to_workspace(Ecto.UUID.t(), Ecto.UUID.t()) ::
          {:ok, WorkspaceAgentJoinSchema.t()} | {:error, Ecto.Changeset.t()}
  def add_to_workspace(workspace_id, agent_id) do
    %WorkspaceAgentJoinSchema{}
    |> WorkspaceAgentJoinSchema.changeset(%{
      workspace_id: workspace_id,
      agent_id: agent_id
    })
    |> Repo.insert()
  end

  @doc """
  Removes an agent from a workspace.

  Deletes the workspace_agents join table entry.

  ## Examples

      iex> remove_from_workspace(workspace_id, agent_id)
      :ok
  """
  @impl true
  @spec remove_from_workspace(Ecto.UUID.t(), Ecto.UUID.t()) :: :ok
  def remove_from_workspace(workspace_id, agent_id) do
    WorkspaceAgentJoinSchema
    |> where([wa], wa.workspace_id == ^workspace_id and wa.agent_id == ^agent_id)
    |> Repo.delete_all()

    :ok
  end

  @doc """
  Lists all agents available in a workspace for the current user.

  Returns a map with two lists:
  - `my_agents`: Agents owned by the current user (both PRIVATE and SHARED)
  - `other_agents`: Agents owned by other users (only SHARED)

  ## Examples

      iex> list_workspace_agents(workspace_id, user_id)
      %{
        my_agents: [%Agent{}, ...],
        other_agents: [%Agent{}, ...]
      }
  """
  @impl true
  @spec list_workspace_agents(Ecto.UUID.t(), Ecto.UUID.t()) :: %{
          my_agents: [AgentSchema.t()],
          other_agents: [AgentSchema.t()]
        }
  def list_workspace_agents(workspace_id, current_user_id) do
    # Get user's own agents in this workspace (both PRIVATE and SHARED)
    my_agents =
      AgentSchema
      |> join(:inner, [a], wa in WorkspaceAgentJoinSchema, on: wa.agent_id == a.id)
      |> where([a, wa], wa.workspace_id == ^workspace_id)
      |> where([a, wa], a.user_id == ^current_user_id)
      |> order_by([a], desc: a.inserted_at)
      |> Repo.all()

    # Get other users' SHARED agents in this workspace
    other_agents =
      AgentSchema
      |> join(:inner, [a], wa in WorkspaceAgentJoinSchema, on: wa.agent_id == a.id)
      |> where([a, wa], wa.workspace_id == ^workspace_id)
      |> where([a, wa], a.user_id != ^current_user_id)
      |> where([a, wa], a.visibility == "SHARED")
      |> order_by([a], desc: a.inserted_at)
      |> Repo.all()

    %{
      my_agents: my_agents,
      other_agents: other_agents
    }
  end

  @doc """
  Checks if an agent is already in a workspace.

  ## Examples

      iex> agent_in_workspace?(workspace_id, agent_id)
      true

      iex> agent_in_workspace?(workspace_id, not_in_workspace_agent_id)
      false
  """
  @impl true
  @spec agent_in_workspace?(Ecto.UUID.t(), Ecto.UUID.t()) :: boolean()
  def agent_in_workspace?(workspace_id, agent_id) do
    WorkspaceAgentJoinSchema
    |> where([wa], wa.workspace_id == ^workspace_id and wa.agent_id == ^agent_id)
    |> Repo.exists?()
  end

  @doc """
  Gets all workspace IDs for an agent.

  ## Examples

      iex> get_agent_workspace_ids(agent_id)
      ["workspace-id-1", "workspace-id-2"]
  """
  @impl true
  @spec get_agent_workspace_ids(Ecto.UUID.t()) :: [Ecto.UUID.t()]
  def get_agent_workspace_ids(agent_id) do
    WorkspaceAgentJoinSchema
    |> where([wa], wa.agent_id == ^agent_id)
    |> select([wa], wa.workspace_id)
    |> Repo.all()
  end

  @doc """
  Synchronizes agent workspace associations atomically.

  Adds the agent to new workspaces and removes it from old ones,
  all within a transaction.

  ## Examples

      iex> sync_agent_workspaces(agent_id, [workspace_id_1, workspace_id_2], [workspace_id_3])
      {:ok, :synced}
  """
  @impl true
  @spec sync_agent_workspaces(Ecto.UUID.t(), MapSet.t(), MapSet.t()) ::
          {:ok, :synced} | {:error, any()}
  def sync_agent_workspaces(agent_id, workspace_ids_to_add, workspace_ids_to_remove) do
    Repo.transaction(fn ->
      # Add to new workspaces
      Enum.each(workspace_ids_to_add, fn workspace_id ->
        add_to_workspace(workspace_id, agent_id)
      end)

      # Remove from old workspaces
      Enum.each(workspace_ids_to_remove, fn workspace_id ->
        remove_from_workspace(workspace_id, agent_id)
      end)

      :synced
    end)
  end
end
