defmodule Jarga.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Workspaces` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary,
    top_level?: true,
    deps: [Jarga.Workspaces, Jarga.Accounts, Jarga.Notifications, Jarga.Repo],
    exports: []

  alias Jarga.Workspaces
  alias Jarga.Workspaces.Domain.Entities.WorkspaceMember
  alias Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema
  alias Jarga.Notifications

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Workspace #{System.unique_integer([:positive])}",
      description: "A test workspace",
      color: "#4A90E2"
    })
  end

  def workspace_fixture(user, attrs \\ %{}) do
    attrs = valid_workspace_attributes(attrs)
    {:ok, workspace} = Workspaces.create_workspace(user, attrs)
    workspace
  end

  @doc """
  Adds a workspace member directly (bypassing invitation flow).

  This is for testing purposes only - bypasses the normal invitation/acceptance flow.

  Returns the workspace_member struct.
  """
  def add_workspace_member_fixture(workspace_id, user, role) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    %WorkspaceMemberSchema{}
    |> WorkspaceMemberSchema.changeset(%{
      workspace_id: workspace_id,
      user_id: user.id,
      email: user.email,
      role: role,
      invited_at: now,
      joined_at: now
    })
    |> Jarga.Repo.insert!()
    |> WorkspaceMember.from_schema()
  end

  @doc """
  Invites a member to a workspace and automatically accepts the invitation.

  This is a convenience function for tests that need members to be immediately
  added to workspaces, similar to the old behavior before notifications were added.

  Returns `{:ok, workspace_member}` on success.
  """
  def invite_and_accept_member(inviter, workspace_id, user_email, role) do
    # Invite the member (creates pending invitation)
    {:ok, {:invitation_sent, _invitation}} =
      Workspaces.invite_member(inviter, workspace_id, user_email, role)

    # Find the user by email
    user = Jarga.Accounts.get_user_by_email_case_insensitive(user_email)

    if user do
      # Get the workspace using the context API with the inviter (who has access)
      workspace = Workspaces.get_workspace!(inviter, workspace_id)

      # Create a notification manually for the test (bypassing the async PubSub subscriber)
      {:ok, notification} =
        Notifications.create_workspace_invitation_notification(%{
          user_id: user.id,
          workspace_id: workspace_id,
          workspace_name: workspace.name,
          invited_by_name: inviter.email,
          role: to_string(role)
        })

      # Accept the invitation through the notification use case (this will broadcast)
      Notifications.accept_workspace_invitation(notification.id, user.id)
    else
      # For non-existent users, return error
      {:error, :user_not_found}
    end
  end
end
