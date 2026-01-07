defmodule Projects.Api.SetupSteps do
  @moduledoc """
  Setup step definitions for Project API Access feature tests.

  These steps create test fixtures (projects, documents) specific to
  Project API access scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.ProjectsFixtures
  import Jarga.DocumentsFixtures

  # ============================================================================
  # PROJECT SETUP STEPS
  # ============================================================================

  step "workspace {string} has a project {string} with slug {string} and description {string}",
       %{args: [workspace_slug, project_name, project_slug, description]} = context do
    workspace = get_workspace_by_slug(context, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context"
    end

    # Get workspace owner from context
    owner =
      get_in(context, [:workspace_owners, workspace_slug]) ||
        raise "Workspace owner for #{workspace_slug} not found. Make sure workspace was created with owner."

    # Use direct fixture to bypass permission check (owner's role may have been changed)
    project =
      project_fixture_direct(owner, workspace, %{
        name: project_name,
        slug: project_slug,
        description: description
      })

    projects = Map.get(context, :projects, %{})

    {:ok, Map.put(context, :projects, Map.put(projects, project_name, project))}
  end

  step "workspace {string} has a project {string} with slug {string}",
       %{args: [workspace_slug, project_name, project_slug]} = context do
    workspace = get_workspace_by_slug(context, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context"
    end

    # Get workspace owner from context
    owner =
      get_in(context, [:workspace_owners, workspace_slug]) ||
        raise "Workspace owner for #{workspace_slug} not found. Make sure workspace was created with owner."

    # Use direct fixture to bypass permission check (owner's role may have been changed)
    project =
      project_fixture_direct(owner, workspace, %{
        name: project_name,
        slug: project_slug
      })

    projects = Map.get(context, :projects, %{})

    {:ok, Map.put(context, :projects, Map.put(projects, project_name, project))}
  end

  step "project {string} has the following documents:", %{args: [project_name]} = context do
    table_data = context.datatable.maps
    project = require_project!(context, project_name)
    workspace = require_workspace_for_project!(context, project)
    owner = get_workspace_owner(context, workspace)

    documents = create_documents(owner, workspace, project, table_data)
    project_documents = Map.get(context, :project_documents, %{})

    # Return context directly for data table steps
    Map.put(context, :project_documents, Map.put(project_documents, project_name, documents))
  end

  # Helper to get workspace by slug from context
  defp get_workspace_by_slug(context, slug) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug) ||
      if(context[:workspace] && context[:workspace].slug == slug, do: context[:workspace])
  end

  defp require_project!(context, project_name) do
    project = Map.get(context[:projects] || %{}, project_name)

    if project do
      project
    else
      raise "Project #{project_name} not found in context"
    end
  end

  defp require_workspace_for_project!(context, project) do
    all_workspaces =
      Map.values(context[:workspaces] || %{}) ++
        Map.values(context[:additional_workspaces] || %{})

    workspace = Enum.find(all_workspaces, fn w -> w.id == project.workspace_id end)

    if workspace do
      workspace
    else
      raise "Workspace for project not found"
    end
  end

  defp get_workspace_owner(context, workspace) do
    get_in(context, [:workspace_owners, workspace.slug]) || context[:current_user]
  end

  defp create_documents(owner, workspace, project, table_data) do
    Enum.map(table_data, fn row ->
      document_fixture(owner, workspace, project, %{
        title: row["Title"],
        content: row["Content"] || "",
        is_public: true
      })
    end)
  end
end
