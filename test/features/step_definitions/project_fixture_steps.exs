defmodule ProjectFixtureSteps do
  @moduledoc """
  Cucumber step definitions for setting up project test fixtures.

  These steps create projects in various states for testing:
  - Projects owned by different users
  - Projects in different workspaces
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Jarga.ProjectsFixtures

  # ============================================================================
  # PROJECT FIXTURES - Basic
  # ============================================================================

  step "a project exists with name {string} owned by {string}",
       %{args: [name, owner_email]} = context do
    owner = get_in(context, [:users, owner_email])
    workspace = context[:workspace]

    project = project_fixture(owner, workspace, %{name: name})

    # Store both as :project (last one) and in :projects map (all of them)
    projects = Map.get(context, :projects, %{})

    {:ok,
     context
     |> Map.put(:project, project)
     |> Map.put(:projects, Map.put(projects, name, project))}
  end

  # ============================================================================
  # PROJECT DATA TABLES
  # ============================================================================

  step "the following projects exist in workspace {string}:",
       %{args: [_workspace_slug]} = context do
    workspace = context[:workspace]
    users = context[:users]

    # Access data table with DOT notation
    table_data = context.datatable.maps

    projects_list =
      Enum.map(table_data, fn row ->
        owner = users[row["owner"]]
        project_fixture(owner, workspace, %{name: row["name"]})
      end)

    # Store in :projects map by name
    projects_map =
      Enum.reduce(projects_list, %{}, fn project, acc ->
        Map.put(acc, project.name, project)
      end)

    # Return context directly for data table steps (no {:ok, })
    context
    |> Map.put(:projects, projects_map)
    |> Map.put(:projects_list, projects_list)
  end

  step "the following documents exist in project {string}:",
       %{args: [project_name]} = context do
    import Jarga.DocumentsFixtures

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name]) || context[:project]

    user =
      context[:current_user] || context[:workspace_owner] ||
        hd(Map.values(context[:users] || %{}))

    # Access data table with DOT notation
    table_data = context.datatable.maps

    documents =
      Enum.map(table_data, fn row ->
        document_fixture(user, workspace, project, %{
          title: row["title"]
        })
      end)

    # Return context directly for data table steps
    Map.put(context, :documents, documents)
  end
end
