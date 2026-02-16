defmodule Agents.Infrastructure.Queries.AgentQueries do
  @moduledoc """
  Composable query functions for agents.

  All functions accept a query and return a query, allowing composition.
  """

  import Ecto.Query, warn: false

  alias Agents.Infrastructure.Schemas.AgentSchema
  alias Agents.Infrastructure.Schemas.WorkspaceAgentJoinSchema

  @doc """
  Returns the base query for agents.

  ## Examples

      iex> base()
      #Ecto.Query<from a in Agent>
  """
  @spec base() :: Ecto.Query.t()
  def base do
    from(a in AgentSchema)
  end

  @doc """
  Filters agents by user_id (ownership).

  ## Examples

      iex> Agent |> for_user(user_id) |> Repo.all()
      [%Agent{}, ...]
  """
  @spec for_user(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def for_user(query \\ base(), user_id) do
    from(a in query, where: a.user_id == ^user_id)
  end

  @doc """
  Filters agents by visibility.

  ## Examples

      iex> Agent |> by_visibility("PRIVATE") |> Repo.all()
      [%Agent{}, ...]

      iex> Agent |> by_visibility("SHARED") |> Repo.all()
      [%Agent{}, ...]
  """
  @spec by_visibility(Ecto.Query.t(), String.t()) :: Ecto.Query.t()
  def by_visibility(query \\ base(), visibility) do
    from(a in query, where: a.visibility == ^visibility)
  end

  @doc """
  Joins with workspace_agents and filters by workspace_id.

  Returns agents that are in the specified workspace.

  ## Examples

      iex> Agent |> in_workspace(workspace_id) |> Repo.all()
      [%Agent{}, ...]
  """
  @spec in_workspace(Ecto.Query.t(), Ecto.UUID.t()) :: Ecto.Query.t()
  def in_workspace(query \\ base(), workspace_id) do
    query
    |> join(:inner, [a], wa in WorkspaceAgentJoinSchema, on: wa.agent_id == a.id)
    |> where([a, wa], wa.workspace_id == ^workspace_id)
  end

  @doc """
  Preloads workspace associations for agents.

  ## Examples

      iex> Agent |> with_workspaces() |> Repo.all()
      [%Agent{workspaces: [...]}, ...]
  """
  @spec with_workspaces(Ecto.Query.t()) :: Ecto.Query.t()
  def with_workspaces(query \\ base()) do
    from(a in query, preload: [:workspaces])
  end
end
