defmodule JargaWeb.Live.PermissionsHelper do
  @moduledoc """
  Helper functions for checking permissions in LiveView components.

  This module provides convenient permission checking functions that can be used
  in LiveView templates to conditionally show/hide UI elements based on user permissions.

  ## Permission Sources

  - **Workspace-level** (edit/delete workspace, invite member): `Identity.Domain.Policies.WorkspacePermissionsPolicy`
  - **Project/document-level** (CRUD on projects, documents): `Jarga.Domain.Policies.DomainPermissionsPolicy`
  """

  alias Identity.Domain.Policies.WorkspacePermissionsPolicy
  alias Jarga.Domain.Policies.DomainPermissionsPolicy

  @doc """
  Checks if a workspace member can edit the workspace.

  ## Examples

      <%= if can_edit_workspace?(@current_member) do %>
        <button>Edit Workspace</button>
      <% end %>
  """
  def can_edit_workspace?(member) do
    WorkspacePermissionsPolicy.can?(member.role, :edit_workspace)
  end

  @doc """
  Checks if a workspace member can delete the workspace.

  ## Examples

      <%= if can_delete_workspace?(@current_member) do %>
        <button>Delete Workspace</button>
      <% end %>
  """
  def can_delete_workspace?(member) do
    WorkspacePermissionsPolicy.can?(member.role, :delete_workspace)
  end

  @doc """
  Checks if a workspace member can create projects.

  ## Examples

      <%= if can_create_project?(@current_member) do %>
        <button>New Project</button>
      <% end %>
  """
  def can_create_project?(member) do
    DomainPermissionsPolicy.can?(member.role, :create_project)
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
    DomainPermissionsPolicy.can?(member.role, :edit_project, owns_resource: owns_project)
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
    DomainPermissionsPolicy.can?(member.role, :delete_project, owns_resource: owns_project)
  end

  @doc """
  Checks if a workspace member can create documents.

  ## Examples

      <%= if can_create_document?(@current_member) do %>
        <button>New Document</button>
      <% end %>
  """
  def can_create_document?(member) do
    DomainPermissionsPolicy.can?(member.role, :create_document)
  end

  @doc """
  Checks if a workspace member can edit a document.

  ## Examples

      <%= if can_edit_document?(@current_member, @document, @current_user) do %>
        <button>Edit Document</button>
      <% end %>
  """
  def can_edit_document?(member, document, current_user) do
    owns_document = document.user_id == current_user.id

    DomainPermissionsPolicy.can?(member.role, :edit_document,
      owns_resource: owns_document,
      is_public: document.is_public
    )
  end

  @doc """
  Checks if a workspace member can delete a document.

  ## Examples

      <%= if can_delete_document?(@current_member, @document, @current_user) do %>
        <button>Delete Document</button>
      <% end %>
  """
  def can_delete_document?(member, document, current_user) do
    owns_document = document.user_id == current_user.id

    if owns_document do
      DomainPermissionsPolicy.can?(member.role, :delete_document, owns_resource: true)
    else
      DomainPermissionsPolicy.can?(member.role, :delete_document,
        owns_resource: false,
        is_public: document.is_public
      )
    end
  end

  @doc """
  Checks if a workspace member can pin/unpin a document.

  ## Examples

      <%= if can_pin_document?(@current_member, @document, @current_user) do %>
        <button>Pin Document</button>
      <% end %>
  """
  def can_pin_document?(member, document, current_user) do
    owns_document = document.user_id == current_user.id

    DomainPermissionsPolicy.can?(member.role, :pin_document,
      owns_resource: owns_document,
      is_public: document.is_public
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

  @doc """
  Checks if a workspace member can create agents.

  Members, admins, and owners can create agents. Guests cannot.

  ## Examples

      <%= if can_create_agent?(@current_member) do %>
        <button>New Agent</button>
      <% end %>
  """
  def can_create_agent?(member) do
    member.role in [:member, :admin, :owner]
  end

  @doc """
  Checks if a workspace member can edit an agent.

  Users can edit their own agents. Admins and owners can edit all agents.

  ## Examples

      <%= if can_edit_agent?(@current_member, @agent, @current_user) do %>
        <button>Edit Agent</button>
      <% end %>
  """
  def can_edit_agent?(member, agent, current_user) do
    owns_agent = agent.created_by_user_id == current_user.id
    owns_agent || member.role in [:admin, :owner]
  end

  @doc """
  Checks if a workspace member can delete an agent.

  Users can delete their own agents. Admins and owners can delete all agents.

  ## Examples

      <%= if can_delete_agent?(@current_member, @agent, @current_user) do %>
        <button>Delete Agent</button>
      <% end %>
  """
  def can_delete_agent?(member, agent, current_user) do
    owns_agent = agent.created_by_user_id == current_user.id
    owns_agent || member.role in [:admin, :owner]
  end
end
