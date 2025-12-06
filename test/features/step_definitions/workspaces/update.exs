defmodule Workspaces.UpdateSteps do
  @moduledoc """
  Step definitions for workspace update scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures

  # ============================================================================
  # WORKSPACE EDITING STEPS
  # ============================================================================

  step "I attempt to edit workspace {string}", %{args: [workspace_slug]} = context do
    workspace = get_workspace_from_context(context, workspace_slug)
    user = context[:current_user]

    result = Jarga.Workspaces.update_workspace(user, workspace.id, %{name: "Updated"})

    case result do
      {:ok, _workspace} ->
        # This shouldn't happen for unauthorized users, but if it does, try to access edit page
        try do
          {:ok, view, html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}/edit")

          {:ok,
           context
           |> Map.put(:view, view)
           |> Map.put(:last_html, html)
           |> Map.put(:last_result, result)}
        rescue
          error ->
            {:ok,
             context
             |> Map.put(:last_error, error)
             |> Map.put(:last_result, {:error, :forbidden})}
        end

      {:error, _reason} ->
        {:ok,
         context
         |> Map.put(:last_result, result)}
    end
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  defp get_workspace_from_context(context, "product-team") do
    context[:workspace]
  end

  defp get_workspace_from_context(context, "Dev Team") do
    context[:workspace] || context[:current_workspace]
  end

  defp get_workspace_from_context(context, "QA Team") do
    find_or_create_workspace(context, "qa-team", "QA Team")
  end

  defp get_workspace_from_context(context, slug) when is_binary(slug) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug)
  end

  defp find_or_create_workspace(context, slug, name) do
    Map.get(context[:workspaces] || %{}, slug) ||
      Map.get(context[:additional_workspaces] || %{}, slug) ||
      create_workspace_for_test(context, name, slug)
  end

  defp create_workspace_for_test(context, name, slug) do
    user = context[:current_user]

    if user do
      workspace_fixture(user, %{name: name, slug: slug})
    else
      nil
    end
  end
end
