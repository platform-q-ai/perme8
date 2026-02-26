defmodule Jarga.WorkspacesFixtures do
  @moduledoc """
  Test helpers for creating workspace entities via the `Identity` context.

  This module delegates to Identity for all workspace-related fixture creation.
  Direct usage of `Identity.WorkspacesFixtures` is preferred for new code.
  """

  # Test fixture module - pure delegation facade to Identity
  use Boundary,
    top_level?: true,
    deps: [
      Identity,
      Identity.Repo,
      Jarga.Workspaces,
      Jarga.Accounts
    ],
    exports: []

  alias Identity.Infrastructure.Schemas.WorkspaceMemberSchema
  alias Identity.Domain.Entities.WorkspaceMember

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Workspace #{System.unique_integer([:positive])}",
      description: "A test workspace",
      color: "#4A90E2"
    })
  end

  def workspace_fixture(user, attrs \\ %{}) do
    attrs = valid_workspace_attributes(attrs)
    {:ok, workspace} = Identity.create_workspace(user, attrs)
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
    # Use Identity.Repo to ensure consistent transaction visibility with user/workspace data
    |> Identity.Repo.insert!()
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
      Identity.invite_member(inviter, workspace_id, user_email, role)

    # Accept the invitation directly through Identity (bypasses notification flow)
    # This is the new pattern: Identity handles workspace membership directly
    user = Identity.get_user_by_email_case_insensitive(user_email)

    if user do
      Identity.accept_invitation_by_workspace(workspace_id, user.id)
    else
      {:error, :user_not_found}
    end
  end
end
