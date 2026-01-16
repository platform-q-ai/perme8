defmodule Jarga.Agents.Application.Policies.AgentPolicy do
  @moduledoc """
  Pure business logic for agent permission rules.

  Defines who can perform actions on agents:
  - EDIT: only owner
  - DELETE: only owner
  - CLONE: owner OR (SHARED agent + workspace member)
  """

  @visibility_shared "SHARED"

  @type agent :: %{user_id: String.t(), visibility: String.t()}
  @type user_id :: String.t()

  @doc """
  Determines if a user can edit an agent.

  Only the agent owner can edit their agent.

  ## Examples

      iex> agent = %{user_id: "user-123"}
      iex> AgentPolicy.can_edit?(agent, "user-123")
      true

      iex> agent = %{user_id: "owner-123"}
      iex> AgentPolicy.can_edit?(agent, "viewer-456")
      false
  """
  @spec can_edit?(agent(), user_id()) :: boolean()
  def can_edit?(%{user_id: owner_id}, user_id) when owner_id == user_id, do: true
  def can_edit?(_agent, _user_id), do: false

  @doc """
  Determines if a user can delete an agent.

  Only the agent owner can delete their agent.

  ## Examples

      iex> agent = %{user_id: "user-123"}
      iex> AgentPolicy.can_delete?(agent, "user-123")
      true

      iex> agent = %{user_id: "owner-123"}
      iex> AgentPolicy.can_delete?(agent, "viewer-456")
      false
  """
  @spec can_delete?(agent(), user_id()) :: boolean()
  def can_delete?(%{user_id: owner_id}, user_id) when owner_id == user_id, do: true
  def can_delete?(_agent, _user_id), do: false

  @doc """
  Determines if a user can clone an agent.

  Clone rules:
  - Owner can always clone their own agent (even PRIVATE)
  - Non-owners can clone SHARED agents if they are workspace members
  - Non-owners cannot clone PRIVATE agents
  - Non-workspace members cannot clone any agents

  ## Examples

      iex> agent = %{user_id: "user-123", visibility: "PRIVATE"}
      iex> AgentPolicy.can_clone?(agent, "user-123", false)
      true

      iex> agent = %{user_id: "owner-123", visibility: "SHARED"}
      iex> AgentPolicy.can_clone?(agent, "viewer-456", true)
      true

      iex> agent = %{user_id: "owner-123", visibility: "PRIVATE"}
      iex> AgentPolicy.can_clone?(agent, "viewer-456", true)
      false
  """
  @spec can_clone?(agent(), user_id(), boolean()) :: boolean()
  def can_clone?(%{user_id: owner_id}, user_id, _workspace_member?)
      when owner_id == user_id do
    true
  end

  def can_clone?(%{visibility: @visibility_shared}, _user_id, true = _workspace_member?) do
    true
  end

  def can_clone?(_agent, _user_id, _workspace_member?) do
    false
  end
end
