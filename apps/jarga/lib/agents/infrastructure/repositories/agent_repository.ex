defmodule Jarga.Agents.Infrastructure.Repositories.AgentRepository do
  @moduledoc """
  Repository for managing user-scoped agents.

  Provides CRUD operations for agents owned by users.
  """

  import Ecto.Query, warn: false

  alias Jarga.Repo
  alias Jarga.Agents.Infrastructure.Schemas.AgentSchema

  @doc """
  Gets a single agent by ID.

  Returns the agent if found, nil otherwise.

  ## Examples

      iex> get(agent_id)
      %Agent{}

      iex> get("non-existent-id")
      nil
  """
  @spec get(Ecto.UUID.t()) :: AgentSchema.t() | nil
  def get(agent_id) do
    Repo.get(AgentSchema, agent_id)
  end

  @doc """
  Gets a single agent if it's owned by the specified user.

  Returns the agent if found and owned by the user, nil otherwise.

  ## Examples

      iex> get_agent_for_user(user_id, agent_id)
      %Agent{}

      iex> get_agent_for_user(user_id, other_users_agent_id)
      nil
  """
  @spec get_agent_for_user(Ecto.UUID.t(), Ecto.UUID.t()) :: AgentSchema.t() | nil
  def get_agent_for_user(user_id, agent_id) do
    AgentSchema
    |> where([a], a.id == ^agent_id and a.user_id == ^user_id)
    |> Repo.one()
  end

  @doc """
  Returns all agents owned by the specified user.

  ## Examples

      iex> list_agents_for_user(user_id)
      [%Agent{}, ...]

      iex> list_agents_for_user(user_with_no_agents_id)
      []
  """
  @spec list_agents_for_user(Ecto.UUID.t(), keyword()) :: [AgentSchema.t()]
  def list_agents_for_user(user_id, _opts \\ []) do
    AgentSchema
    |> where([a], a.user_id == ^user_id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Creates a new agent.

  ## Examples

      iex> create_agent(%{user_id: user_id, name: "My Agent"})
      {:ok, %Agent{}}

      iex> create_agent(%{name: "Invalid"})
      {:error, %Ecto.Changeset{}}
  """
  @spec create_agent(map()) :: {:ok, AgentSchema.t()} | {:error, Ecto.Changeset.t()}
  def create_agent(attrs) do
    %AgentSchema{}
    |> AgentSchema.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates an agent.

  ## Examples

      iex> update_agent(agent, %{name: "New Name"})
      {:ok, %Agent{}}

      iex> update_agent(agent, %{visibility: "INVALID"})
      {:error, %Ecto.Changeset{}}
  """
  @spec update_agent(AgentSchema.t(), map()) ::
          {:ok, AgentSchema.t()} | {:error, Ecto.Changeset.t()}
  def update_agent(%AgentSchema{} = agent, attrs) do
    agent
    |> AgentSchema.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Updates an agent's inserted_at timestamp.
  """
  def update_timestamp(agent_id, timestamp) do
    AgentSchema
    |> where([a], a.id == ^agent_id)
    |> Repo.update_all(set: [inserted_at: timestamp])
  end

  @doc """
  Deletes an agent.

  Cascade deletes all workspace_agents entries via database constraint.

  ## Examples

      iex> delete_agent(agent)
      {:ok, %Agent{}}
  """
  @spec delete_agent(AgentSchema.t()) :: {:ok, AgentSchema.t()} | {:error, Ecto.Changeset.t()}
  def delete_agent(%AgentSchema{} = agent) do
    Repo.delete(agent)
  end

  @doc """
  Lists all agents viewable by a user.

  Returns:
  - User's own agents (PRIVATE + SHARED)
  - All other SHARED agents

  Used when viewing agents without workspace context.

  ## Examples

      iex> list_viewable_agents(user_id)
      [%Agent{}, ...]
  """
  @spec list_viewable_agents(Ecto.UUID.t()) :: [AgentSchema.t()]
  def list_viewable_agents(user_id) do
    AgentSchema
    |> where([a], a.user_id == ^user_id or a.visibility == "SHARED")
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end
end
