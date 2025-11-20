defmodule Jarga.Agents.Policies.VisibilityPolicy do
  @moduledoc """
  Pure business logic for determining agent visibility.

  Implements visibility rules:
  - PRIVATE agents: only owner can view
  - SHARED agents: owner + workspace members can view
  """

  @visibility_shared "SHARED"

  @type agent :: %{user_id: String.t(), visibility: String.t()}
  @type user_id :: String.t()

  @doc """
  Determines if a user can view an agent based on ownership and visibility rules.

  ## Rules
  - Owner can always view their agent (regardless of visibility or workspace membership)
  - PRIVATE agents: only owner can view
  - SHARED agents: owner + workspace members can view
  - Non-workspace members cannot view SHARED agents

  ## Parameters
  - `agent` - Map with `:user_id` and `:visibility` fields
  - `user_id` - ID of the user attempting to view
  - `workspace_member?` - Boolean indicating if user is a workspace member

  ## Examples

      iex> agent = %{user_id: "user-123", visibility: "PRIVATE"}
      iex> VisibilityPolicy.can_view_agent?(agent, "user-123", false)
      true

      iex> agent = %{user_id: "owner-123", visibility: "SHARED"}
      iex> VisibilityPolicy.can_view_agent?(agent, "viewer-456", true)
      true

      iex> agent = %{user_id: "owner-123", visibility: "PRIVATE"}
      iex> VisibilityPolicy.can_view_agent?(agent, "viewer-456", true)
      false
  """
  @spec can_view_agent?(agent(), user_id(), boolean()) :: boolean()
  def can_view_agent?(%{user_id: owner_id}, user_id, _workspace_member?)
      when owner_id == user_id do
    true
  end

  def can_view_agent?(%{visibility: @visibility_shared}, _user_id, true = _workspace_member?) do
    true
  end

  def can_view_agent?(_agent, _user_id, _workspace_member?) do
    false
  end
end
