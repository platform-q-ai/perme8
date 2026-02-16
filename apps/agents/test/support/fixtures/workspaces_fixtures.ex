defmodule Agents.Test.WorkspacesFixtures do
  @moduledoc """
  Test helpers for creating workspace entities via the `Identity` context.

  This module replicates the workspace fixture logic from Jarga.WorkspacesFixtures
  using only the Identity public API, avoiding cross-app test support dependencies.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary,
    top_level?: true,
    deps: [Identity, Identity.Repo],
    exports: []

  alias Identity.Domain.Entities.WorkspaceMember
  alias Identity.Infrastructure.Schemas.WorkspaceMemberSchema

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
end
