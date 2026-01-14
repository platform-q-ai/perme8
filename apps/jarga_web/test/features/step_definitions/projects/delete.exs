defmodule Projects.DeleteSteps do
  @moduledoc """
  Cucumber step definitions for project deletion scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Jarga.Projects

  # ============================================================================
  # PROJECT DELETION ACTIONS
  # ============================================================================

  step "I delete the project", context do
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to project show page via UI
    {:ok, show_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Click the delete button (this will trigger a confirmation dialog in real browser)
    # In tests, we can directly trigger the phx-click event
    show_view
    |> element("button[phx-click='delete_project']")
    |> render_click()

    # The delete should redirect to workspace page
    assert_redirect(show_view, ~p"/app/workspaces/#{workspace.slug}")

    # Verify via UI - mount the workspace page and check project is NOT there
    {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Verify the deleted project name does NOT appear in the HTML
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    refute html =~ name_escaped

    {:ok,
     context
     |> Map.put(:last_result, {:ok, project})
     |> Map.put(:last_html, html)}
  end

  step "I attempt to delete the project", context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to project show page via UI to ensure user can access it
    {:ok, _show_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Test authorization by calling the API (what handle_event does internally)
    result = Projects.delete_project(user, workspace.id, project.id)

    {:ok, context |> Map.put(:last_result, result)}
  end

  step "I delete project {string}", %{args: [project_name]} = context do
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page via UI
    {:ok, show_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Click the delete button (this will trigger a confirmation dialog in real browser)
    # In tests, we can directly trigger the phx-click event
    show_view
    |> element("button[phx-click='delete_project']")
    |> render_click()

    # The delete should redirect to workspace page
    assert_redirect(show_view, ~p"/app/workspaces/#{workspace.slug}")

    # Verify via UI - mount the workspace page and check project is NOT there
    {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Verify the deleted project name does NOT appear in the HTML
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    refute html =~ name_escaped

    {:ok,
     context
     |> Map.put(:last_result, {:ok, project})
     |> Map.put(:last_html, html)}
  end

  step "I attempt to delete project {string}", %{args: [project_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page via UI to ensure user can access it
    {:ok, _show_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Test authorization by calling the API (what handle_event does internally)
    result = Projects.delete_project(user, workspace.id, project.id)

    {:ok, context |> Map.put(:last_result, result)}
  end

  step "I attempt to delete a project in workspace {string}",
       %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    conn = context[:conn]

    # Try to navigate to workspace page via UI to test access
    # This might fail for non-members, which is expected behavior
    try do
      {:ok, _view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")
    rescue
      _ ->
        # User doesn't have access to workspace, which is part of the authorization test
        # Continue with API call to test project deletion authorization
        :ok
    end

    # Try to delete with a fake project ID (what would happen if user tried to delete non-existent project)
    result = Projects.delete_project(user, workspace.id, Ecto.UUID.generate())

    {:ok, context |> Map.put(:last_result, result)}
  end
end
