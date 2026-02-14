defmodule Jarga.Workspaces do
  @moduledoc """
  Facade for workspace management operations.

  This module delegates all workspace operations to the `Identity` app.

  ## Migration Note

  This facade delegates to Identity for all workspace operations.
  Direct usage of `Identity` module is preferred for new code.
  """

  # Boundary configuration - pure delegation facade to Identity
  use Boundary,
    top_level?: true,
    deps: [Identity],
    exports: []

  # =============================================================================
  # DELEGATED TO IDENTITY - Workspace operations
  # =============================================================================

  ## Workspace CRUD

  defdelegate list_workspaces_for_user(user), to: Identity
  defdelegate create_workspace(user, attrs), to: Identity
  defdelegate get_workspace(user, id), to: Identity
  defdelegate get_workspace!(user, id), to: Identity
  defdelegate get_workspace_by_slug(user, slug), to: Identity
  defdelegate get_workspace_by_slug!(user, slug), to: Identity
  defdelegate get_workspace_and_member_by_slug(user, slug), to: Identity
  defdelegate delete_workspace(user, workspace_id), to: Identity

  def update_workspace(user, workspace_id, attrs, opts \\ []),
    do: Identity.update_workspace(user, workspace_id, attrs, opts)

  ## Membership verification

  defdelegate verify_membership(user, workspace_id), to: Identity
  defdelegate member?(user_id, workspace_id), to: Identity
  defdelegate member_by_slug?(user_id, workspace_slug), to: Identity
  defdelegate get_member(user, workspace_id), to: Identity

  ## Member management

  def invite_member(inviter, workspace_id, email, role, opts \\ []),
    do: Identity.invite_member(inviter, workspace_id, email, role, opts)

  defdelegate list_members(workspace_id), to: Identity
  defdelegate change_member_role(actor, workspace_id, member_email, new_role), to: Identity
  defdelegate remove_member(actor, workspace_id, member_email), to: Identity

  ## Invitations

  defdelegate accept_pending_invitations(user), to: Identity
  defdelegate accept_invitation_by_workspace(workspace_id, user_id), to: Identity
  defdelegate decline_invitation_by_workspace(workspace_id, user_id), to: Identity
  defdelegate list_pending_invitations_with_details(email), to: Identity
  defdelegate create_notifications_for_pending_invitations(user), to: Identity

  ## Changesets (for forms)

  defdelegate change_workspace(), to: Identity

  def change_workspace(workspace, attrs \\ %{}),
    do: Identity.change_workspace(workspace, attrs)
end
