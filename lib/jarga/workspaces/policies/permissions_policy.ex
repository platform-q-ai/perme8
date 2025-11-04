defmodule Jarga.Workspaces.Policies.PermissionsPolicy do
  @moduledoc """
  Domain-level permission policy for workspace members.

  Defines what actions each role can perform on workspaces, projects, and pages.
  This is pure domain logic with no infrastructure dependencies.

  ## Role Hierarchy
  - **Guest**: Can only view content, no editing, creating or deleting
  - **Member**: Can create and manage their own content, edit shared pages
  - **Admin**: Can manage all projects, shared pages, and workspace. Cannot manage non-shared pages or delete workspace
  - **Owner**: Full control except managing non-public pages of others
  """

  @type role :: :guest | :member | :admin | :owner
  @type action :: atom()
  @type context :: keyword()

  @doc """
  Checks if a role has permission to perform an action.

  ## Examples

      # Simple permission check
      iex> can?(:guest, :view_workspace)
      true

      # Permission check with context
      iex> can?(:member, :edit_page, owns_resource: true, is_public: false)
      true

      iex> can?(:member, :edit_page, owns_resource: false, is_public: false)
      false
  """
  @spec can?(role(), action(), context()) :: boolean()

  # Define default parameter once
  def can?(role, action, context \\ [])

  # Workspace permissions
  def can?(_role, :view_workspace, _context), do: true

  def can?(role, :edit_workspace, _context)
      when role in [:admin, :owner],
      do: true

  def can?(:owner, :delete_workspace, _context), do: true

  # Project permissions - viewing
  def can?(_role, :view_project, _context), do: true

  # Project permissions - creating
  def can?(role, :create_project, _context)
      when role in [:member, :admin, :owner],
      do: true

  # Project permissions - editing
  def can?(role, :edit_project, owns_resource: true)
      when role in [:member, :admin, :owner],
      do: true

  def can?(role, :edit_project, owns_resource: false)
      when role in [:admin, :owner],
      do: true

  # Project permissions - deleting
  def can?(role, :delete_project, owns_resource: true)
      when role in [:member, :admin, :owner],
      do: true

  def can?(role, :delete_project, owns_resource: false)
      when role in [:admin, :owner],
      do: true

  # Page permissions - viewing
  def can?(_role, :view_page, _context), do: true

  # Page permissions - creating
  def can?(role, :create_page, _context)
      when role in [:member, :admin, :owner],
      do: true

  # Page permissions - editing own page
  def can?(role, :edit_page, owns_resource: true, is_public: _)
      when role in [:member, :admin, :owner],
      do: true

  # Page permissions - editing shared (public) page
  # Members and admins can edit shared pages, but owner cannot (per requirements)
  def can?(role, :edit_page, owns_resource: false, is_public: true)
      when role in [:member, :admin],
      do: true

  # Page permissions - deleting own page
  def can?(role, :delete_page, owns_resource: true)
      when role in [:member, :admin, :owner],
      do: true

  # Page permissions - deleting others' shared page
  # Admin can only delete shared pages (owner cannot per requirements)
  def can?(:admin, :delete_page, owns_resource: false, is_public: true), do: true

  # Page permissions - pinning own page
  def can?(role, :pin_page, owns_resource: true, is_public: _)
      when role in [:member, :admin, :owner],
      do: true

  # Page permissions - pinning shared (public) page
  def can?(role, :pin_page, owns_resource: false, is_public: true)
      when role in [:member, :admin, :owner],
      do: true

  # Default: deny all other permissions
  def can?(_role, _action, _context), do: false
end
