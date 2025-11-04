defmodule Jarga.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Projects` context.
  """

  # Test fixture module - top-level boundary for test data creation
  use Boundary, top_level?: true, deps: [Jarga.Projects], exports: []

  alias Jarga.Projects

  def valid_project_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Project #{System.unique_integer([:positive])}",
      description: "A test project",
      color: "#10B981"
    })
  end

  def project_fixture(user, workspace, attrs \\ %{}) do
    attrs = valid_project_attributes(attrs)
    {:ok, project} = Projects.create_project(user, workspace.id, attrs)
    project
  end
end
