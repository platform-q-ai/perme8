defmodule Projects.UpdateSteps do
  @moduledoc """
  Cucumber step definitions for project update scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Jarga.Projects

  # ============================================================================
  # PROJECT UPDATE ACTIONS
  # ============================================================================

  step "I update the project name to {string}", %{args: [new_name]} = context do
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page via UI
    {:ok, edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Submit the update form with new name
    edit_view
    |> form("#project-form", project: %{name: new_name})
    |> render_submit()

    # Get the updated project from database (name might have changed slug)
    user = context[:current_user]
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    updated_project = Enum.find(projects, fn p -> p.id == project.id end)

    # Verify via UI - mount the project show page with new slug
    {:ok, _show_view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{updated_project.slug}")

    # Verify the updated name appears in the HTML
    name_escaped = Phoenix.HTML.html_escape(new_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok,
     context
     |> Map.put(:project, updated_project)
     |> Map.put(:last_result, {:ok, updated_project})
     |> Map.put(:last_html, html)}
  end

  step "I attempt to update the project name to {string}", %{args: [new_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page via UI to ensure user can access it
    {:ok, _edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Test authorization by calling the API (what handle_event does internally)
    result = Projects.update_project(user, workspace.id, project.id, %{name: new_name})

    {:ok, context |> Map.put(:last_result, result)}
  end

  step "I attempt to update {string} name to {string}",
       %{args: [project_name, new_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to edit page via UI to ensure user can access it
    {:ok, _edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Test authorization by calling the API (what handle_event does internally)
    result = Projects.update_project(user, workspace.id, project.id, %{name: new_name})

    {:ok, context |> Map.put(:last_result, result)}
  end

  step "I update {string} name to {string}", %{args: [project_name, new_name]} = context do
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to edit page via UI
    {:ok, edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Submit the update form with new name
    edit_view
    |> form("#project-form", project: %{name: new_name})
    |> render_submit()

    # Get the updated project from database (name might have changed slug)
    user = context[:current_user]
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    updated_project = Enum.find(projects, fn p -> p.id == project.id end)

    # Verify via UI - mount the project show page with new slug
    {:ok, _show_view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{updated_project.slug}")

    # Verify the updated name appears in the HTML
    name_escaped = Phoenix.HTML.html_escape(new_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    # Update in projects map
    updated_projects = Map.put(context[:projects], project_name, updated_project)

    {:ok,
     context
     |> Map.put(:project, updated_project)
     |> Map.put(:projects, updated_projects)
     |> Map.put(:last_result, {:ok, updated_project})
     |> Map.put(:last_html, html)}
  end

  step "I update the project description to {string}", %{args: [description]} = context do
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page via UI
    {:ok, edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Submit the update form with new description
    edit_view
    |> form("#project-form", project: %{description: description})
    |> render_submit()

    # Get the updated project from database
    user = context[:current_user]
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    updated_project = Enum.find(projects, fn p -> p.id == project.id end)

    {:ok,
     context
     |> Map.put(:project, updated_project)
     |> Map.put(:last_result, {:ok, updated_project})}
  end

  step "I update the project color to {string}", %{args: [color]} = context do
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page via UI
    {:ok, edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Submit the update form with new color
    edit_view
    |> form("#project-form", project: %{color: color})
    |> render_submit()

    # Get the updated project from database
    user = context[:current_user]
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    updated_project = Enum.find(projects, fn p -> p.id == project.id end)

    {:ok,
     context
     |> Map.put(:project, updated_project)
     |> Map.put(:last_result, {:ok, updated_project})}
  end
end
