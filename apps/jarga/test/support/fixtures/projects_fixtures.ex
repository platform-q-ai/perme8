defmodule Jarga.ProjectsFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `Jarga.Projects` context.
  """

  # Test fixture module - top-level boundary for test data creation
  # Needs access to context + layer boundaries for fixture creation
  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Projects,
      Jarga.Projects.Domain,
      Jarga.Projects.Infrastructure,
      Jarga.Repo
    ],
    exports: []

  alias Jarga.Projects
  alias Jarga.Projects.Domain.Entities.Project
  alias Jarga.Projects.Infrastructure.Schemas.ProjectSchema

  def valid_project_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      name: "Test Project #{System.unique_integer([:positive])}",
      description: "A test project",
      color: "#10B981"
    })
  end

  @doc """
  Creates a project fixture using the context API (checks permissions).
  Use this when the user has the appropriate role.
  """
  def project_fixture(user, workspace, attrs \\ %{}) do
    attrs = valid_project_attributes(attrs)
    {:ok, project} = Projects.create_project(user, workspace.id, attrs)
    project
  end

  @doc """
  Creates a project directly in the database, bypassing permission checks.

  This is for testing purposes only - bypasses the normal authorization flow.
  Use this for test setup when the user's role may not allow project creation
  (e.g., when testing with a guest user who needs existing projects).

  Returns the project domain entity.
  """
  def project_fixture_direct(user, workspace, attrs \\ %{}) do
    attrs = valid_project_attributes(attrs)

    # Generate slug from name if not provided
    slug = attrs[:slug] || generate_slug(attrs[:name], workspace.id)

    %ProjectSchema{}
    |> ProjectSchema.changeset(%{
      name: attrs[:name],
      slug: slug,
      description: attrs[:description],
      color: attrs[:color],
      user_id: user.id,
      workspace_id: workspace.id
    })
    |> Identity.Repo.insert!()
    |> Project.from_schema()
  end

  # Simple slug generation for fixtures (doesn't need collision handling for tests)
  defp generate_slug(name, _workspace_id) do
    name
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\s-]/, "")
    |> String.replace(~r/\s+/, "-")
    |> String.trim("-")
  end
end
