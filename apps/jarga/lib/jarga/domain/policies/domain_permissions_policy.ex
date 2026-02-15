defmodule Jarga.Domain.Policies.DomainPermissionsPolicy do
  @moduledoc """
  Domain-level permission policy for project and document actions.

  Defines what actions each role can perform on projects and documents.
  This is pure domain logic with no infrastructure dependencies.

  Extracted from the original `Jarga.Workspaces.Application.Policies.PermissionsPolicy`,
  covering only project and document permissions.

  Workspace-level permissions (`:view_workspace`, `:edit_workspace`, `:delete_workspace`,
  `:invite_member`) are handled by `Identity.Domain.Policies.WorkspacePermissionsPolicy`.

  ## Role Hierarchy
  - **Guest**: Can only view content, no editing, creating or deleting
  - **Member**: Can create and manage their own content, edit shared documents
  - **Admin**: Can manage all projects, shared documents. Cannot manage non-shared documents or delete workspace
  - **Owner**: Full control except managing non-public documents of others
  """

  @type role :: :guest | :member | :admin | :owner
  @type action :: atom()
  @type context :: keyword()

  @doc """
  Checks if a role has permission to perform a project or document action.

  ## Examples

      # Simple permission check
      iex> can?(:guest, :view_project)
      true

      # Permission check with context
      iex> can?(:member, :edit_document, owns_resource: true, is_public: false)
      true

      iex> can?(:member, :edit_document, owns_resource: false, is_public: false)
      false
  """
  @spec can?(role(), action(), context()) :: boolean()

  # Define default parameter once
  def can?(role, action, context \\ [])

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

  # Document permissions - viewing
  def can?(_role, :view_document, _context), do: true

  # Document permissions - creating
  def can?(role, :create_document, _context)
      when role in [:member, :admin, :owner],
      do: true

  # Document permissions - editing own document
  def can?(role, :edit_document, owns_resource: true, is_public: _)
      when role in [:member, :admin, :owner],
      do: true

  # Document permissions - editing shared (public) document
  def can?(role, :edit_document, owns_resource: false, is_public: true)
      when role in [:member, :admin],
      do: true

  # Document permissions - deleting own document
  def can?(role, :delete_document, owns_resource: true)
      when role in [:member, :admin, :owner],
      do: true

  # Document permissions - deleting others' shared document
  def can?(:admin, :delete_document, owns_resource: false, is_public: true), do: true

  # Document permissions - pinning own document
  def can?(role, :pin_document, owns_resource: true, is_public: _)
      when role in [:member, :admin, :owner],
      do: true

  # Document permissions - pinning shared (public) document
  def can?(role, :pin_document, owns_resource: false, is_public: true)
      when role in [:member, :admin, :owner],
      do: true

  # Default: deny all other permissions
  def can?(_role, _action, _context), do: false
end
