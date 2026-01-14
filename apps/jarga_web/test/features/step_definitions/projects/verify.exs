defmodule Projects.VerifySteps do
  @moduledoc """
  Cucumber step definitions for project verification and assertions.

  Includes:
  - Creation assertions
  - Update assertions
  - Deletion assertions
  - Listing assertions
  - PubSub notification assertions
  - Document association assertions
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository
  alias Jarga.Projects.Infrastructure.Repositories.ProjectRepository

  # ============================================================================
  # PROJECT CREATION ASSERTIONS
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

  # ============================================================================
  # PROJECT UPDATE ASSERTIONS
  # ============================================================================

  step "the project {string} name should be {string}",
       %{args: [project_name, expected_name]} = context do
    workspace = context[:workspace]
    project = get_in(context, [:projects, project_name])
    conn = context[:conn]

    # Reload from database
    reloaded_project = ProjectRepository.get(project.id)
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
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = ProjectRepository.get(project.id)
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
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = ProjectRepository.get(project.id)
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
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = ProjectRepository.get(project.id)
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
    workspace = context[:workspace]
    project = context[:project]
    conn = context[:conn]

    # Reload from database
    reloaded_project = ProjectRepository.get(project.id)
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
  # PROJECT DELETION ASSERTIONS
  # ============================================================================

  step "the project should be deleted successfully", context do
    case context[:last_result] do
      {:ok, _deleted_project} ->
        {:ok, context}

      {:error, reason} ->
        flunk("Expected project to be deleted successfully, but got error: #{inspect(reason)}")
    end
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
    project = context[:viewed_project] || context[:project]

    documents = DocumentRepository.list_by_project_id(project.id)

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

  step "the new project should appear in their workspace view", context do
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

  # ============================================================================
  # PUBSUB NOTIFICATION ASSERTIONS
  # ============================================================================

  step "a project created notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project creation action
    # This is typically done in a previous step like "I am viewing the project"
    # or "user is viewing workspace"

    # Verify we received the project created broadcast
    assert_receive {:project_added, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "a project updated notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project update action

    # Verify we received the project updated broadcast
    assert_receive {:project_updated, project_id, name}, 1000
    assert project_id == project.id
    assert name == project.name

    {:ok, context}
  end

  step "a project deleted notification should be broadcast", context do
    project = context[:project]

    # NOTE: Subscription must happen BEFORE the project deletion action

    # Verify we received the project deleted broadcast
    assert_receive {:project_removed, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "user {string} should receive a project created notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_added, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  step "user {string} should receive a project updated notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_updated, project_id, name}, 1000
    assert project_id == project.id
    assert name == project.name

    {:ok, context}
  end

  step "user {string} should receive a project deleted notification",
       %{args: [_user_email]} = context do
    project = context[:project]

    # The user should have subscribed in a "user is viewing workspace" step
    # Verify the PubSub broadcast was received
    assert_receive {:project_removed, project_id}, 1000
    assert project_id == project.id

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT ASSOCIATION ASSERTIONS
  # ============================================================================

  step "the document {string} should still exist", %{args: [doc_title]} = context do
    document = DocumentRepository.get_by_title(doc_title)

    assert document != nil, "Expected document '#{doc_title}' to still exist"
    {:ok, context |> Map.put(:document, document)}
  end

  step "the document should no longer be associated with a project", context do
    document = context[:document]
    # Reload from database
    reloaded_document = DocumentRepository.get_by_id(document.id)

    assert reloaded_document.project_id == nil,
           "Expected document to have no project association"

    {:ok, context}
  end

  step "the document should still be associated with project {string}",
       %{args: [project_name]} = context do
    document = context[:document]
    project = get_in(context, [:projects, project_name])
    # Reload from database
    reloaded_document = DocumentRepository.get_by_id(document.id)

    assert reloaded_document.project_id == project.id,
           "Expected document to still be associated with project '#{project_name}'"

    {:ok, context}
  end

  step "I should still be able to view document {string}", %{args: [doc_title]} = context do
    document = DocumentRepository.get_by_title(doc_title)

    assert document != nil, "Expected to be able to view document '#{doc_title}'"
    {:ok, context}
  end
end
