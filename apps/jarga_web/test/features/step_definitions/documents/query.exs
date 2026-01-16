defmodule Documents.QuerySteps do
  @moduledoc """
  Step definitions for document viewing, listing and filtering.

  Covers:
  - Viewing documents
  - Attempting to view (with authorization)
  - Read-only indicators
  - Edit permissions
  - Access control assertions
  - Breadcrumbs
  - Listing workspace/project documents
  - Filtering by visibility
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  alias Jarga.Documents.Infrastructure.Repositories.DocumentRepository

  # ============================================================================
  # DOCUMENT VIEWING STEPS
  # ============================================================================

  step "I view document {string} in workspace {string}",
       %{args: [_title, _workspace_slug]} = context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    # View document via LiveView
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    {:ok, context |> Map.put(:last_html, html)}
  end

  step "I attempt to view document {string} in workspace {string}",
       %{args: [_title, _workspace_slug]} = context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    # Try to view document (should fail for unauthorized users)
    try do
      result = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

      case result do
        {:ok, _view, html} ->
          {:ok, context |> Map.put(:last_html, html) |> Map.put(:last_result, {:ok, :accessed})}

        {:error, {:redirect, _redirect}} ->
          # LiveView redirected (likely due to authorization failure)
          {:ok, context |> Map.put(:last_result, {:error, :unauthorized})}

        error ->
          {:ok, context |> Map.put(:last_result, error)}
      end
    rescue
      error ->
        # Caught an exception (e.g., authorization check raised)
        {:ok,
         context |> Map.put(:last_error, error) |> Map.put(:last_result, {:error, :unauthorized})}
    end
  end

  step "I am viewing the document", context do
    workspace = context[:workspace]
    document = context[:document]
    conn = context[:conn]

    result = live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}")

    case result do
      {:ok, view, html} ->
        {:ok,
         context
         |> Map.put(:view, view)
         |> Map.put(:last_html, html)}

      error ->
        {:ok, context |> Map.put(:last_result, error)}
    end
  end

  step "I view the document", context do
    {workspace, document, conn, current_user} = extract_view_context(context)
    fresh_document = verify_document_ownership(document, current_user)
    navigate_to_document_page(conn, workspace, fresh_document, current_user, context)
  end

  defp extract_view_context(context) do
    workspace = context[:workspace] || raise "No workspace. Set :workspace in a prior step."
    document = context[:document] || raise "No document. Set :document in a prior step."
    conn = context[:conn] || raise "No connection. Ensure conn is set in context."
    current_user = context[:current_user] || raise "No user. Run 'Given I am logged in' first."
    {workspace, document, conn, current_user}
  end

  defp verify_document_ownership(document, current_user) do
    fresh_document =
      DocumentRepository.get_by_id(document.id) ||
        raise "Document not found in database: id=#{document.id}"

    assert fresh_document.user_id == current_user.id,
           "Document user_id mismatch: document.user_id=#{fresh_document.user_id}, current_user.id=#{current_user.id}"

    fresh_document
  end

  defp navigate_to_document_page(conn, workspace, document, current_user, context) do
    case live(conn, ~p"/app/workspaces/#{workspace.slug}/documents/#{document.slug}") do
      {:ok, view, html} ->
        {:ok, context |> Map.put(:view, view) |> Map.put(:last_html, html)}

      error ->
        flunk(build_view_error_message(error, document, current_user, workspace))
    end
  end

  defp build_view_error_message(error, document, current_user, workspace) do
    "Failed to view document: #{inspect(error)}\n" <>
      "DocumentSchema: slug=#{document.slug}, workspace_id=#{document.workspace_id}, " <>
      "user_id=#{document.user_id}, is_public=#{document.is_public}, project_id=#{inspect(document.project_id)}\n" <>
      "User: id=#{current_user.id}\n" <>
      "Workspace: id=#{workspace.id}, slug=#{workspace.slug}"
  end

  # ============================================================================
  # VIEWING ASSERTIONS
  # ============================================================================

  step "I should see the document content", context do
    html = context[:last_html]
    document = context[:document]

    assert html =~ document.title
    {:ok, context}
  end

  step "I should be able to edit the document", context do
    html = context[:last_html]

    # Check for edit button or edit form presence
    assert html =~ "edit" or html =~ "Edit"
    {:ok, context}
  end

  step "I should see a read-only indicator", context do
    html = context[:last_html]

    assert html =~ "read-only" or html =~ "Read Only" or html =~ "view only"
    {:ok, context}
  end

  step "I should not be able to edit the document", context do
    html = context[:last_html]

    # Should NOT have edit buttons/forms
    refute html =~ ~r/id="edit.*button"/
    {:ok, context}
  end

  step "I should see breadcrumbs showing {string}", %{args: [breadcrumb_text]} = context do
    html = context[:last_html]

    # Breadcrumb text like "Product Team > Mobile App > Specs"
    # needs to check for each part in the HTML breadcrumbs
    parts = String.split(breadcrumb_text, " > ")

    Enum.each(parts, fn part ->
      assert html =~ part, "Expected breadcrumb to contain '#{part}'"
    end)

    {:ok, context}
  end

  # ============================================================================
  # DOCUMENT LISTING STEPS
  # ============================================================================

  step "I list documents in workspace {string}", %{args: [_workspace_slug]} = context do
    workspace = context[:workspace]
    conn = context[:conn]

    # List documents via workspace show page (shows workspace-level documents)
    {:ok, _view, html} = live(conn, ~p"/app/workspaces/#{workspace.slug}")

    {:ok, context |> Map.put(:last_html, html)}
  end

  step "I list documents for project {string}", %{args: [project_name]} = context do
    workspace = context[:workspace]
    # Get the specific project by name
    project = get_in(context, [:projects, project_name]) || context[:project]
    conn = context[:conn]

    # List documents via project show page (shows project documents)
    {:ok, _view, html} =
      live(conn, ~p"/app/workspaces/#{workspace.slug}/projects/#{project.slug}")

    {:ok, context |> Map.put(:last_html, html)}
  end

  step "I should see documents:", context do
    html = context[:last_html]
    table_data = context.datatable.maps

    Enum.each(table_data, fn row ->
      title_escaped = Phoenix.HTML.html_escape(row["title"]) |> Phoenix.HTML.safe_to_string()
      assert html =~ title_escaped
    end)

    # Return context directly for data table steps
    context
  end

  step "I should not see documents:", context do
    html = context[:last_html]
    table_data = context.datatable.maps

    Enum.each(table_data, fn row ->
      title_escaped = Phoenix.HTML.html_escape(row["title"]) |> Phoenix.HTML.safe_to_string()
      refute html =~ title_escaped
    end)

    # Return context directly for data table steps
    context
  end
end
