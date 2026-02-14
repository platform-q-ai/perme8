defmodule Identity.Domain.Policies.WorkspacePermissionsPolicy do
  @moduledoc """
  Domain-level permission policy for workspace-level actions.

  Defines what actions each role can perform on workspaces and membership.
  This is pure domain logic with no infrastructure dependencies.

  Extracted from the original `Jarga.Workspaces.Application.Policies.PermissionsPolicy`,
  covering only workspace-level permissions:
  - `:view_workspace`, `:edit_workspace`, `:delete_workspace`, `:invite_member`

  Project and document permissions are handled by `Jarga.Domain.Policies.DomainPermissionsPolicy`.

  ## Role Hierarchy
  - **Guest**: Can only view workspace
  - **Member**: Can only view workspace
  - **Admin**: Can view, edit workspace, and invite members
  - **Owner**: Full workspace control (view, edit, delete, invite)
  """

  @type role :: :guest | :member | :admin | :owner
  @type action :: atom()
  @type context :: keyword()

  @doc """
  Checks if a role has permission to perform a workspace-level action.

  ## Examples

      iex> can?(:guest, :view_workspace)
      true

      iex> can?(:admin, :edit_workspace)
      true

      iex> can?(:member, :delete_workspace)
      false
  """
  @spec can?(role(), action(), context()) :: boolean()

  def can?(role, action, context \\ [])

  # Workspace permissions
  def can?(_role, :view_workspace, _context), do: true

  def can?(role, :edit_workspace, _context)
      when role in [:admin, :owner],
      do: true

  def can?(:owner, :delete_workspace, _context), do: true

  # Member management permissions
  def can?(role, :invite_member, _context)
      when role in [:admin, :owner],
      do: true

  # Default: deny all other permissions
  def can?(_role, _action, _context), do: false
end
