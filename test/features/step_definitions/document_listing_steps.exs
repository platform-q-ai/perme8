defmodule DocumentListingSteps do
  @moduledoc """
  Cucumber step definitions for document listing and filtering.

  Covers:
  - Listing workspace documents
  - Listing project documents
  - Filtering by visibility
  - Data table assertions (should see/not see)
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase

  import Phoenix.LiveViewTest
  import ExUnit.Assertions

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
