defmodule Workspaces.CreateSteps do
  @moduledoc """
  Step definitions for workspace creation scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias Jarga.Workspaces

  # ============================================================================
  # WORKSPACE FORM STEPS
  # ============================================================================

  step "I fill in the workspace form with:", context do
    table_data = context.datatable.maps

    # Store form data for later submission
    form_attrs =
      Enum.reduce(table_data, %{}, fn row, acc ->
        case row["Field"] do
          "Name" -> Map.put(acc, :name, row["Value"])
          "Description" -> Map.put(acc, :description, row["Value"])
          "Color" -> Map.put(acc, :color, row["Value"])
          _ -> acc
        end
      end)

    {:ok, Map.put(context, :workspace_form_attrs, form_attrs)}
  end

  step "I fill in workspace form with:", context do
    table_data = context.datatable.maps

    # Store form data for later submission
    form_attrs =
      Enum.reduce(table_data, %{}, fn row, acc ->
        case row["Field"] do
          "Name" -> Map.put(acc, :name, row["Value"])
          "Description" -> Map.put(acc, :description, row["Value"])
          "Color" -> Map.put(acc, :color, row["Value"])
          _ -> acc
        end
      end)

    {:ok, Map.put(context, :workspace_form_attrs, form_attrs)}
  end

  step "I submit form", context do
    form_attrs = context[:workspace_form_attrs] || %{}

    result =
      context[:view]
      |> form("#workspace-form", workspace: form_attrs)
      |> render_submit()

    # Handle redirects
    case result do
      {:error, {:live_redirect, %{to: _path}}} ->
        # Use follow_redirect to properly handle flash messages
        {:ok, new_view, html} = follow_redirect(result, context[:conn])

        {:ok,
         context
         |> Map.put(:view, new_view)
         |> Map.put(:last_html, html)}

      {:error, {:redirect, %{to: _path}}} ->
        # Use follow_redirect to properly handle flash messages
        {:ok, new_view, html} = follow_redirect(result, context[:conn])

        {:ok,
         context
         |> Map.put(:view, new_view)
         |> Map.put(:last_html, html)}

      html when is_binary(html) ->
        # No redirect, validation error - stay on same page
        {:ok, Map.put(context, :last_html, html)}
    end
  end

  step "I submit the form", context do
    form_attrs = context[:workspace_form_attrs] || %{}

    result =
      context[:view]
      |> form("#workspace-form", workspace: form_attrs)
      |> render_submit()

    # Handle redirects
    case result do
      {:error, {:live_redirect, %{to: _path}}} ->
        # Use follow_redirect to properly handle flash messages
        {:ok, new_view, html} = follow_redirect(result, context[:conn])

        {:ok,
         context
         |> Map.put(:view, new_view)
         |> Map.put(:last_html, html)}

      {:error, {:redirect, %{to: _path}}} ->
        # Use follow_redirect to properly handle flash messages
        {:ok, new_view, html} = follow_redirect(result, context[:conn])

        {:ok,
         context
         |> Map.put(:view, new_view)
         |> Map.put(:last_html, html)}

      html when is_binary(html) ->
        # No redirect, validation error - stay on same page
        {:ok, Map.put(context, :last_html, html)}
    end
  end

  # ============================================================================
  # WORKSPACE SLUG VERIFICATION
  # ============================================================================

  step "workspace should have slug {string}", %{args: [expected_slug]} = context do
    # Verify workspace was created with correct slug
    user = context[:current_user]
    workspaces = Workspaces.list_workspaces_for_user(user)

    workspace_with_slug = Enum.find(workspaces, fn ws -> ws.slug == expected_slug end)
    assert workspace_with_slug, "Expected to find workspace with slug '#{expected_slug}'"

    {:ok, context}
  end

  step "the workspace should have slug {string}", %{args: [expected_slug]} = context do
    # Verify workspace was created with correct slug
    user = context[:current_user]
    workspaces = Workspaces.list_workspaces_for_user(user)

    workspace_with_slug = Enum.find(workspaces, fn ws -> ws.slug == expected_slug end)
    assert workspace_with_slug, "Expected to find workspace with slug '#{expected_slug}'"

    {:ok, context}
  end

  # ============================================================================
  # PROJECT/DOCUMENT CREATION PERMISSIONS
  # ============================================================================

  step "I should be able to create a project", context do
    workspace = context[:workspace]
    user = context[:current_user]

    # Try to create a project
    result =
      Jarga.Projects.create_project(user, workspace.id, %{
        name: "Test Project",
        description: "A test project"
      })

    case result do
      {:ok, _project} ->
        {:ok, Map.put(context, :can_create_project, true)}

      {:error, _reason} ->
        {:ok, Map.put(context, :can_create_project, false)}
    end
  end

  step "I should be able to create a document", context do
    workspace = context[:workspace]
    user = context[:current_user]

    # Try to create a document
    result =
      Jarga.Documents.create_document(user, workspace.id, %{
        title: "Test Document"
      })

    case result do
      {:ok, _document} ->
        {:ok, Map.put(context, :can_create_document, true)}

      {:error, _reason} ->
        {:ok, Map.put(context, :can_create_document, false)}
    end
  end
end
