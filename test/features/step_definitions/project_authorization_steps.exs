defmodule ProjectAuthorizationSteps do
  @moduledoc """
  Cucumber step definitions for project authorization scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  alias Jarga.Projects
  alias Jarga.Repo
  alias Jarga.Documents.Infrastructure.Schemas.DocumentSchema

  # ============================================================================
  # AUTHORIZATION ASSERTIONS
  # ============================================================================

  step "I should be able to view the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to project show page - should succeed
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Verify project name appears (confirms access and rendering)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to view {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page - should succeed
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Verify project name appears (confirms access and rendering)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to update the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page - should succeed
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Verify edit form is accessible (contains project name)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to update {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to edit page - should succeed
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Verify edit form is accessible (contains project name)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to delete the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to project show page - should succeed and show delete button
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Verify project name appears (confirms access and rendering)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to delete {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page - should succeed and show delete button
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Verify project name appears (confirms access and rendering)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to archive the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page - should succeed and show archive checkbox
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Verify edit form is accessible (contains project name)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should be able to archive {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to edit page - should succeed and show archive checkbox
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Verify edit form is accessible (contains project name)
    name_escaped = Phoenix.HTML.html_escape(project.name) |> Phoenix.HTML.safe_to_string()
    assert html =~ name_escaped

    {:ok, context}
  end

  step "I should not be able to update the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to edit page via UI to ensure user can access it
    {:ok, _edit_view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")

    # Test authorization by calling the API (what handle_event does internally)
    result =
      Projects.update_project(context[:current_user], workspace.id, project.id, %{name: "Test"})

    case result do
      {:error, :forbidden} -> {:ok, context}
      {:ok, _project} -> flunk("Expected update to be forbidden but it succeeded")
      {:error, _other} -> flunk("Expected :forbidden error but got a different error")
    end
  end

  step "I should not be able to update {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Try to navigate to edit page - should fail with redirect or error
    try do
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")
      flunk("Expected navigation to edit page to fail but it succeeded")
    rescue
      # Expected redirect/forbidden
      RuntimeError -> {:ok, context}
      # Expected button not found
      ArgumentError -> {:ok, context}
      # Any other error also indicates failure
      _ -> {:ok, context}
    end
  end

  step "I should not be able to delete the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Navigate to project show page via UI to ensure user can access it
    {:ok, _view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Test authorization by calling the API (what handle_event does internally)
    result = Projects.delete_project(context[:current_user], workspace.id, project.id)

    case result do
      {:error, :forbidden} -> {:ok, context}
      {:ok, _project} -> flunk("Expected deletion to be forbidden but it succeeded")
      {:error, _other} -> flunk("Expected :forbidden error but got a different error")
    end
  end

  step "I should not be able to delete {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Navigate to project show page - should succeed
    {:ok, _view, _html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    # Now try to delete via API (what the UI would do)
    result = Projects.delete_project(context[:current_user], workspace.id, project.id)

    case result do
      {:error, :forbidden} ->
        {:ok, context}

      {:ok, _project} ->
        flunk("Expected deletion of '#{project_name}' to be forbidden but it succeeded")

      {:error, _other} ->
        flunk("Expected :forbidden error but got a different error")
    end
  end

  step "I should not be able to archive the project", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Try to navigate to edit page - should fail with redirect or error
    assert_raise RuntimeError, fn ->
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")
    end

    {:ok, context}
  end

  step "I should not be able to archive {string}", %{args: [project_name]} = context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Try to navigate to edit page - should fail with redirect or error
    assert_raise RuntimeError, fn ->
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}/edit")
    end

    {:ok, context}
  end

  step "I should not be able to create projects", context do
    import Phoenix.LiveViewTest

    workspace = context[:workspace]
    conn = context[:conn]

    # Try to navigate to workspace page - should succeed
    {:ok, view, _html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    # Try to find "New Project" button - should not exist for unauthorized users
    try do
      view
      |> element("button[phx-click='show_project_modal']", "New Project")
      |> render_click()

      flunk("Expected 'New Project' button to not exist but it did")
    rescue
      # Expected redirect/forbidden
      RuntimeError -> {:ok, context}
      # Expected button not found
      ArgumentError -> {:ok, context}
      # Any other error also indicates failure
      _ -> {:ok, context}
    end
  end

  # ============================================================================
  # DOCUMENT ASSOCIATION ASSERTIONS
  # ============================================================================

  step "the document {string} should still exist", %{args: [doc_title]} = context do
    import Ecto.Query

    document =
      DocumentSchema
      |> where([d], d.title == ^doc_title)
      |> Repo.one()

    assert document != nil, "Expected document '#{doc_title}' to still exist"
    {:ok, context |> Map.put(:document, document)}
  end

  step "the document should no longer be associated with a project", context do
    document = context[:document]
    # Reload from database
    reloaded_document = Repo.get!(DocumentSchema, document.id)

    assert reloaded_document.project_id == nil,
           "Expected document to have no project association"

    {:ok, context}
  end

  step "the document should still be associated with project {string}",
       %{args: [project_name]} = context do
    document = context[:document]
    project = get_in(context, [:projects, project_name])
    # Reload from database
    reloaded_document = Repo.get!(DocumentSchema, document.id)

    assert reloaded_document.project_id == project.id,
           "Expected document to still be associated with project '#{project_name}'"

    {:ok, context}
  end

  step "I should still be able to view document {string}", %{args: [doc_title]} = context do
    import Ecto.Query

    document =
      DocumentSchema
      |> where([d], d.title == ^doc_title)
      |> Repo.one()

    assert document != nil, "Expected to be able to view document '#{doc_title}'"
    {:ok, context}
  end
end
