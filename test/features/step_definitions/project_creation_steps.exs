defmodule ProjectCreationSteps do
  @moduledoc """
  Cucumber step definitions for project creation scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  alias Jarga.Projects

  # ============================================================================
  # PROJECT CREATION - When Steps
  # ============================================================================

  step "I create a project with name {string} in workspace {string}",
       %{args: [name, _workspace_slug]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    conn = context[:conn]

    # Mount the workspace page (UI)
    {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Click the "New Project" button to open modal (use first button)
    view
    |> element("button[phx-click='show_project_modal']", "New Project")
    |> render_click()

    # Submit the project creation form
    view
    |> form("#project-form", project: %{name: name})
    |> render_submit()

    # The page should now show the project in the list
    html = render(view)
    name_escaped = Phoenix.HTML.html_escape(name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    # Get the created project from the database for further assertions
    # If there was a project in context before (fixture), exclude it to get the newly created one
    existing_project_id = context[:project] && context[:project].id

    projects = Projects.list_projects_for_workspace(context[:current_user], workspace.id)

    matching_projects =
      projects
      |> Enum.filter(fn p -> p.name == name end)
      |> Enum.reject(fn p -> existing_project_id && p.id == existing_project_id end)

    # If still multiple matches (shouldn't happen), sort by inserted_at and id
    project =
      case matching_projects do
        [] ->
          # No new project found, use the existing one (shouldn't happen in normal flow)
          List.first(Enum.filter(projects, fn p -> p.name == name end))

        [single] ->
          single

        multiple ->
          # Multiple matches, get the most recent one
          Enum.sort_by(
            multiple,
            fn p -> {p.inserted_at, p.id} end,
            fn {t1, id1}, {t2, id2} ->
              case DateTime.compare(t1, t2) do
                :gt -> true
                :lt -> false
                :eq -> id1 > id2
              end
            end
          )
          |> List.first()
      end

    assert project != nil,
           "Project '#{name}' was not found in database after creation. Projects: #{inspect(Enum.map(projects, & &1.name))}"

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
    import Phoenix.LiveViewTest

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

  # ============================================================================
  # PROJECT CREATION - Then Steps (Assertions)
  # ============================================================================

  step "the project should be created successfully", context do
    case context[:last_result] do
      {:ok, project} ->
        assert project.id != nil
        {:ok, context |> Map.put(:project, project)}

      {:error, reason} ->
        flunk("Expected project to be created successfully, but got error: #{inspect(reason)}")
    end
  end

  step "the project should have slug {string}", %{args: [expected_slug]} = context do
    project = context[:project]
    assert project.slug == expected_slug
    {:ok, context}
  end

  step "the project should be owned by {string}", %{args: [owner_email]} = context do
    project = context[:project]
    owner = get_in(context, [:users, owner_email])
    assert project.user_id == owner.id
    {:ok, context}
  end

  step "the project should not be default", context do
    project = context[:project]
    assert project.is_default == false
    {:ok, context}
  end

  step "the project should have a unique slug like {string}", %{args: [slug_pattern]} = context do
    project = context[:project]
    # Pattern like "mobile-app-*" means starts with "mobile-app-" followed by something
    base_slug = String.replace(slug_pattern, "*", "")
    assert String.starts_with?(project.slug, base_slug)
    assert String.length(project.slug) > String.length(base_slug)
    {:ok, context}
  end

  step "the project slug should be URL-safe", context do
    project = context[:project]
    # URL-safe means no spaces, special characters except hyphens and underscores
    assert project.slug =~ ~r/^[a-z0-9\-_]+$/
    {:ok, context}
  end

  step "the project slug should not contain special characters", context do
    project = context[:project]
    # Should only contain lowercase letters, numbers, hyphens, underscores
    assert project.slug =~ ~r/^[a-z0-9\-_]+$/
    {:ok, context}
  end

  step "the project should not be created", context do
    case context[:last_result] do
      {:error, _changeset} ->
        {:ok, context}

      {:ok, _project} ->
        flunk("Expected project creation to fail, but it succeeded")
    end
  end
end
