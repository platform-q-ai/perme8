defmodule Projects.CreateSteps do
  @moduledoc """
  Cucumber step definitions for project creation scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import Jarga.Test.StepHelpers, only: [find_newly_created_project: 3]

  alias Jarga.Projects

  # ============================================================================
  # PROJECT CREATION - When Steps
  # ============================================================================

  step "I create a project with name {string} in workspace {string}",
       %{args: [name, _workspace_slug]} = context do
    workspace = context[:workspace]
    conn = context[:conn]
    existing_project_id = context[:project] && context[:project].id

    # Mount the workspace page and create project via UI
    {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    view
    |> element("button[phx-click='show_project_modal']", "New Project")
    |> render_click()

    view
    |> form("#project-form", project: %{name: name})
    |> render_submit()

    html = render(view)
    assert html =~ Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()

    # Find the newly created project
    projects = Projects.list_projects_for_workspace(context[:current_user], workspace.id)
    project = find_newly_created_project(projects, name, existing_project_id)

    assert project != nil,
           "Project '#{name}' not found. Projects: #{inspect(Enum.map(projects, & &1.name))}"

    {:ok,
     context
     |> Map.put(:project, project)
     |> Map.put(:last_result, {:ok, project})
     |> Map.put(:last_html, html)}
  end

  step "I attempt to create a project with name {string} in workspace {string}",
       %{args: [name, _workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]

    # Handle empty name case with direct API call
    if name == "" do
      result = Projects.create_project(user, workspace.id, %{name: ""})
      {:ok, context |> Map.put(:last_result, result)}
    else
      # For non-empty names, use direct API call to test authorization
      # This avoids complex UI interaction issues in test environment
      result = Projects.create_project(user, workspace.id, %{name: name})
      {:ok, context |> Map.put(:last_result, result)}
    end
  end

  step "I create a project with the following details in workspace {string}:",
       %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    conn = context[:conn]

    # Access data table with DOT notation
    table_data = context.datatable.maps
    row = List.first(table_data)

    attrs = %{
      name: row["name"],
      description: row["description"],
      color: row["color"]
    }

    # Navigate to workspace page (UI)
    {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Click the "New Project" button to open modal
    view
    |> element("button[phx-click='show_project_modal']", "New Project")
    |> render_click()

    # Submit the project creation form with all fields
    view
    |> form("#project-form", project: attrs)
    |> render_submit()

    # The page should now show the project in the list
    html = render(view)
    name_escaped = Phoenix.HTML.html_escape(attrs.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    # Get the created project from the database
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    project = Enum.find(projects, fn p -> p.name == attrs.name end)

    assert project != nil,
           "Project '#{attrs.name}' was not found in database after creation"

    {:ok,
     context
     |> Map.put(:project, project)
     |> Map.put(:last_result, {:ok, project})
     |> Map.put(:last_html, html)}
  end

  step "I attempt to create a project without a name in workspace {string}",
       %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]

    # Direct API call to test validation - this will return an Ecto.Changeset error
    result = Projects.create_project(user, workspace.id, %{name: ""})

    {:ok, context |> Map.put(:last_result, result)}
  end
end
