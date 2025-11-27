defmodule ProjectActionSteps do
  @moduledoc """
  Cucumber step definitions for project update, delete, and other actions.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  alias Jarga.Projects
  alias Jarga.Repo
  alias Jarga.Projects.Domain.Entities.Project

  # ============================================================================
  # PROJECT UPDATE ACTIONS
  # ============================================================================

  step "I update the project name to {string}", %{args: [new_name]} = context do
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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

  step "the project {string} name should be {string}",
       %{args: [project_name, expected_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Reload from database
    reloaded_project = Repo.get!(Project, project.id)
    assert reloaded_project.name == expected_name

    # Verify via UI - mount the project show page and check the name appears
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{reloaded_project.slug}")

    # Verify the expected name appears in the HTML
    name_escaped = Phoenix.HTML.html_escape(expected_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "the project name should be {string}", %{args: [expected_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = Repo.get!(Project, project.id)
    assert reloaded_project.name == expected_name

    # Verify via UI - mount the project show page and check the name appears
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{reloaded_project.slug}")

    # Verify the expected name appears in the HTML
    name_escaped = Phoenix.HTML.html_escape(expected_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "the project name should remain {string}", %{args: [expected_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = Repo.get!(Project, project.id)
    assert reloaded_project.name == expected_name

    # Verify via UI - mount the project show page and check the name appears
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{reloaded_project.slug}")

    # Verify the expected name appears in the HTML
    name_escaped = Phoenix.HTML.html_escape(expected_name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "the project description should be {string}", %{args: [expected_description]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = Repo.get!(Project, project.id)
    assert reloaded_project.description == expected_description

    # Verify via UI - mount the project show page and check the description appears
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{reloaded_project.slug}")

    # Verify the expected description appears in the HTML if it's not nil
    if expected_description do
      desc_escaped =
        Phoenix.HTML.html_escape(expected_description) |> Phoenix.HTML.safe_to_string()

      assert html =~ desc_escaped
    end

    {:ok, context}
  end

  step "the project color should be {string}", %{args: [expected_color]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = Repo.get!(Project, project.id)
    assert reloaded_project.color == expected_color

    # Verify via UI - mount the project show page and check the color appears
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{reloaded_project.slug}")

    # Verify the expected color appears in the HTML (as a background-color style)
    if expected_color do
      assert html =~ expected_color
    end

    {:ok, context}
  end

  # ============================================================================
  # PROJECT DELETION ACTIONS
  # ============================================================================

  step "I delete the project", context do
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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
    import Phoenix.LiveViewTest

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

  step "the project should be deleted successfully", context do
    case context[:last_result] do
      {:ok, _deleted_project} ->
        {:ok, context}

      {:error, reason} ->
        flunk("Expected project to be deleted successfully, but got error: #{inspect(reason)}")
    end
  end
end
