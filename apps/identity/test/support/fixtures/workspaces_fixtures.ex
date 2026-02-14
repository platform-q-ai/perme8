defmodule Identity.WorkspacesFixtures do
  @moduledoc """
  Test fixtures for Identity workspace entities.

  This module provides test helpers for creating workspace-related test data
  within the Identity app's test suite.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary,
    top_level?: true,
    deps: [Identity, Identity.Repo],
    exports: []

  alias Identity.Domain.Entities.{Workspace, WorkspaceMember}
  alias Identity.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}

  def valid_workspace_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Workspace #{System.unique_integer([:positive])}",
      slug: "test-workspace-#{System.unique_integer([:positive])}",
      description: "A test workspace",
      color: "#4A90E2"
    })
  end

  @doc """
  Creates a workspace and adds the given user as owner.
  Returns the workspace domain entity.
  """
  def workspace_fixture(user, attrs \\ %{}) do
    attrs = valid_workspace_attributes(attrs)

    {:ok, workspace_schema} =
      %WorkspaceSchema{}
      |> WorkspaceSchema.changeset(attrs)
      |> Identity.Repo.insert()

    now = DateTime.utc_now() |> DateTime.truncate(:second)

    # Add the user as owner
    {:ok, _member} =
      %WorkspaceMemberSchema{}
      |> WorkspaceMemberSchema.changeset(%{
        workspace_id: workspace_schema.id,
        user_id: user.id,
        email: user.email,
        role: :owner,
        invited_at: now,
        joined_at: now
      })
      |> Identity.Repo.insert()

    Workspace.from_schema(workspace_schema)
  end

  @doc """
  Adds a workspace member directly (bypassing invitation flow).
  Returns the workspace_member domain entity.
  """
  def add_workspace_member_fixture(workspace_id, user, role) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    {:ok, schema} =
      %WorkspaceMemberSchema{}
      |> WorkspaceMemberSchema.changeset(%{
        workspace_id: workspace_id,
        user_id: user.id,
        email: user.email,
        role: role,
        invited_at: now,
        joined_at: now
      })
      |> Identity.Repo.insert()

    WorkspaceMember.from_schema(schema)
  end

  @doc """
  Creates a pending invitation (no user_id, no joined_at).
  Returns the workspace_member domain entity.
  """
  def pending_invitation_fixture(workspace_id, email, role, opts \\ []) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    invited_by = Keyword.get(opts, :invited_by)

    attrs = %{
      workspace_id: workspace_id,
      email: email,
      role: role,
      invited_at: now
    }

    attrs = if invited_by, do: Map.put(attrs, :invited_by, invited_by), else: attrs

    {:ok, schema} =
      %WorkspaceMemberSchema{}
      |> WorkspaceMemberSchema.changeset(attrs)
      |> Identity.Repo.insert()

    WorkspaceMember.from_schema(schema)
  end
end
