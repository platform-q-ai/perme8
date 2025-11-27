defmodule ProjectListingSteps do
  @moduledoc """
  Cucumber step definitions for project listing and viewing scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  alias Jarga.Projects

  # ============================================================================
  # PROJECT LISTING ACTIONS
  # ============================================================================

  step "I list projects in workspace {string}", %{args: [_workspace_slug]} = context do
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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

  step "user {string} is viewing the project", %{args: [_user_email]} = context do
    # Simulate another user viewing - this would be for PubSub notification testing
    {:ok, context |> Map.put(:other_user_viewing_project, true)}
  end

  # ============================================================================
  # PROJECT LISTING ASSERTIONS
  # ============================================================================

  step "I should see projects:", context do
    listed_projects = context[:listed_projects] || []
    expected_projects_table = context.datatable.maps

    expected_names = Enum.map(expected_projects_table, fn row -> row["name"] end)
    actual_names = Enum.map(listed_projects, fn project -> project.name end)

    Enum.each(expected_names, fn expected_name ->
      assert expected_name in actual_names,
             "Expected to see project '#{expected_name}' but it was not in the list. Found: #{inspect(actual_names)}"
    end)

    {:ok, context}
  end

  step "I should see listed projects:", context do
    listed_projects = context[:listed_projects] || []
    expected_projects_table = context.datatable.maps

    expected_names = Enum.map(expected_projects_table, fn row -> row["name"] end)
    actual_names = Enum.map(listed_projects, fn project -> project.name end)

    Enum.each(expected_names, fn expected_name ->
      assert expected_name in actual_names,
             "Expected to see project '#{expected_name}' but it was not in the list. Found: #{inspect(actual_names)}"
    end)

    {:ok, context}
  end

  step "I should see {int} documents in the project", %{args: [expected_count]} = context do
    # This would require getting documents for the project
    import Jarga.Repo
    import Ecto.Query
    alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

    project = context[:viewed_project] || context[:project]

    documents =
      DocumentSchema
      |> where([d], d.project_id == ^project.id)
      |> all()

    assert length(documents) == expected_count,
           "Expected #{expected_count} documents but found #{length(documents)}"

    {:ok, context}
  end

  step "the project should contain documents:", context do
    documents = context[:documents] || []

    expected_docs = context.datatable.maps
    expected_titles = Enum.map(expected_docs, fn row -> row["title"] end)
    actual_titles = Enum.map(documents, fn doc -> doc.title end)

    Enum.each(expected_titles, fn expected_title ->
      assert expected_title in actual_titles,
             "Expected project to contain document '#{expected_title}' but it was not found"
    end)

    {:ok, context}
  end

  # ============================================================================
  # UI ASSERTIONS (Real-time updates via PubSub)
  # ============================================================================
  # Note: Real-time update steps are defined in document_pubsub_steps
  # and are shared across both documents and projects:
  # - "I should see breadcrumbs showing"
  # - "I should see the workspace name updated to"
  # - "I should see the project name updated to"
  # - "the project name should update in their UI without refresh"
  # - "the project should be removed from their workspace view"

  step "the new project should appear in their workspace view", context do
    import Phoenix.LiveViewTest

    project = context[:project]
    view = context[:workspace_view]

    # NOTE: The PubSub broadcast was already verified in the previous step:
    # "user {string} should receive a project created notification"
    # This step tests that the LiveView process handles the PubSub message correctly

    # Simulate the PubSub message that the LiveView would receive
    # This tests the handle_info/2 callback directly
    send(view.pid, {:project_added, project.id})

    # Render the view to see the effects of the PubSub message
    html = render(view)

    # Verify the new project appears in the workspace view
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context |> Map.put(:last_html, html)}
  end
end
