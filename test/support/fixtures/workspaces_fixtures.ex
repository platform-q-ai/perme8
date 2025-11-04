defmodule Jarga.WorkspacesFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Workspaces` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Workspaces], exports: []

  alias Jarga.Workspaces

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
end
