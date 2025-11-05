defmodule JargaWeb.Live.PermissionsHelper do
  @moduledoc """
  Helper functions for checking permissions in LiveView components.

  This module provides convenient permission checking functions that can be used
  in LiveView templates to conditionally show/hide UI elements based on user permissions.
  """

  alias Jarga.Workspaces.Policies.PermissionsPolicy

  @doc """
  Checks if a workspace member can edit the workspace.

  ## Examples

      <%= if can_edit_workspace?(@current_member) do %>
        <button>Edit Workspace</button>
      <% end %>
  """
  def can_edit_workspace?(member) do
    PermissionsPolicy.can?(member.role, :edit_workspace)
  end

  @doc """
  Checks if a workspace member can delete the workspace.

  ## Examples

      <%= if can_delete_workspace?(@current_member) do %>
        <button>Delete Workspace</button>
      <% end %>
  """
  def can_delete_workspace?(member) do
    PermissionsPolicy.can?(member.role, :delete_workspace)
  end

  @doc """
  Checks if a workspace member can create projects.

  ## Examples

      <%= if can_create_project?(@current_member) do %>
        <button>New Project</button>
      <% end %>
  """
  def can_create_project?(member) do
    PermissionsPolicy.can?(member.role, :create_project)
  end

  @doc """
  Checks if a workspace member can edit a project.

  ## Examples

      <%= if can_edit_project?(@current_member, @project, @current_user) do %>
        <button>Edit Project</button>
      <% end %>
  """
  def can_edit_project?(member, project, current_user) do
    owns_project = project.user_id == current_user.id
    PermissionsPolicy.can?(member.role, :edit_project, owns_resource: owns_project)
  end

  @doc """
  Checks if a workspace member can delete a project.

  ## Examples

      <%= if can_delete_project?(@current_member, @project, @current_user) do %>
        <button>Delete Project</button>
      <% end %>
  """
  def can_delete_project?(member, project, current_user) do
    owns_project = project.user_id == current_user.id
    PermissionsPolicy.can?(member.role, :delete_project, owns_resource: owns_project)
  end

  @doc """
  Checks if a workspace member can create pages.

  ## Examples

      <%= if can_create_page?(@current_member) do %>
        <button>New Page</button>
      <% end %>
  """
  def can_create_page?(member) do
    PermissionsPolicy.can?(member.role, :create_page)
  end

  @doc """
  Checks if a workspace member can edit a page.

  ## Examples

      <%= if can_edit_page?(@current_member, @page, @current_user) do %>
        <button>Edit Page</button>
      <% end %>
  """
  def can_edit_page?(member, page, current_user) do
    owns_page = page.user_id == current_user.id

    PermissionsPolicy.can?(member.role, :edit_page,
      owns_resource: owns_page,
      is_public: page.is_public
    )
  end

  @doc """
  Checks if a workspace member can delete a page.

  ## Examples

      <%= if can_delete_page?(@current_member, @page, @current_user) do %>
        <button>Delete Page</button>
      <% end %>
  """
  def can_delete_page?(member, page, current_user) do
    owns_page = page.user_id == current_user.id

    if owns_page do
      PermissionsPolicy.can?(member.role, :delete_page, owns_resource: true)
    else
      PermissionsPolicy.can?(member.role, :delete_page,
        owns_resource: false,
        is_public: page.is_public
      )
    end
  end

  @doc """
  Checks if a workspace member can pin/unpin a page.

  ## Examples

      <%= if can_pin_page?(@current_member, @page, @current_user) do %>
        <button>Pin Page</button>
      <% end %>
  """
  def can_pin_page?(member, page, current_user) do
    owns_page = page.user_id == current_user.id

    PermissionsPolicy.can?(member.role, :pin_page,
      owns_resource: owns_page,
      is_public: page.is_public
    )
  end

  @doc """
  Checks if a workspace member can manage other members (invite, change roles, remove).

  Admins and owners can manage members, but cannot change the owner role.

  ## Examples

      <%= if can_manage_members?(@current_member) do %>
        <button>Manage Members</button>
      <% end %>
  """
  def can_manage_members?(member) do
    member.role in [:admin, :owner]
  end
end
