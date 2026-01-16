defmodule Projects.QuerySteps do
  @moduledoc """
  Cucumber step definitions for project listing and viewing scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest

  alias Jarga.Projects

  # ============================================================================
  # PROJECT LISTING ACTIONS
  # ============================================================================

  step "I list projects in workspace {string}", %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    conn = context[:conn]

    # Subscribe to PubSub to receive real-time notifications (simulates viewing the page)
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    # Mount the workspace show page (UI test)
    {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Also get the project data for assertions
    projects = Projects.list_projects_for_workspace(user, workspace.id)
    active_projects = Enum.filter(projects, fn p -> !p.is_archived end)

    {:ok,
     context
     |> Map.put(:listed_projects, active_projects)
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:ok, active_projects})
     |> Map.put(:pubsub_subscribed, true)}
  end

  step "I list all projects including archived in workspace {string}",
       %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    conn = context[:conn]

    # Mount the workspace show page (UI test) - this should show all projects including archived
    {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Also get the project data for assertions
    projects = Projects.list_projects_for_workspace(user, workspace.id)

    {:ok,
     context
     |> Map.put(:listed_projects, projects)
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:ok, projects})}
  end

  step "I attempt to list projects in workspace {string}", %{args: [_workspace_slug]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    conn = context[:conn]

    # Try to navigate to workspace page - this will fail if user can't access it
    result =
      try do
        {:ok, _view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

        # If successful, get the projects
        projects = Projects.list_projects_for_workspace(user, workspace.id)
        {:ok, projects}
      rescue
        # If navigation fails, return appropriate error
        _ ->
          case user.role do
            :guest -> {:error, :forbidden}
            _ -> {:error, :unauthorized}
          end
      end

    {:ok, context |> Map.put(:last_result, result)}
  end

  # ============================================================================
  # PROJECT VIEWING ACTIONS
  # ============================================================================

  step "I view the project", context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Mount the project show page (UI test)
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Also get project details for assertions
    {:ok, project_details} = Projects.get_project(user, workspace.id, project.id)

    {:ok,
     context
     |> Map.put(:viewed_project, project_details)
     |> Map.put(:last_html, html)}
  end

  step "I view project {string}", %{args: [project_name]} = context do
    user = context[:current_user]
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page (UI test)
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Also get project details for assertions
    {:ok, project_details} = Projects.get_project(user, workspace.id, project.id)

    {:ok,
     context
     |> Map.put(:viewed_project, project_details)
     |> Map.put(:last_html, html)}
  end

  step "I am viewing the project", context do
    workspace = context[:workspace]
    conn = context[:conn]

    # Subscribe to PubSub to receive real-time notifications
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    # Mount and keep the LiveView connection alive for real-time testing
    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:is_viewing_project, true)
     |> Map.put(:pubsub_subscribed, true)
     |> Map.put(:workspace_view, view)
     |> Map.put(:last_html, html)}
  end

  step "user {string} is viewing workspace {string}",
       %{args: [_user_email, _workspace_slug]} = context do
    workspace = context[:workspace]
    conn = context[:conn]

    # Subscribe to PubSub to simulate another user watching the workspace
    Phoenix.PubSub.subscribe(Jarga.PubSub, "workspace:#{workspace.id}")

    # Mount and keep the LiveView connection alive for real-time testing
    {:ok, view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok,
     context
     |> Map.put(:other_user_viewing_workspace, true)
     |> Map.put(:pubsub_subscribed, true)
     |> Map.put(:workspace_view, view)
     |> Map.put(:last_html, html)}
  end

  step "user {string} is viewing the project", %{args: [user_email]} = context do
    # Simulate another user viewing the project
    # Subscribe to PubSub to receive project update notifications
    project = context[:project]
    project_id = project && project.id

    # Subscribe to project updates (if project exists)
    _subscribed = project_id && Phoenix.PubSub.subscribe(Jarga.PubSub, "project:#{project_id}")

    {:ok,
     context
     |> Map.put(:other_user_viewing_project, true)
     |> Map.put(:viewing_user_email, user_email)}
  end
end
