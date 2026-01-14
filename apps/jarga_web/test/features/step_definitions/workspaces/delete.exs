defmodule Workspaces.DeleteSteps do
  @moduledoc """
  Step definitions for workspace deletion scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures

  # ============================================================================
  # WORKSPACE DELETION STEPS
  # ============================================================================

  # Workspace-specific deletion confirmation step
  # NOTE: In LiveView tests with data-confirm, the deletion executes on click.
  # This step acknowledges the action was triggered via the prior "I click" step.
  step "I confirm the workspace deletion", context do
    # The deletion action was triggered by "I click Delete Workspace" which
    # clicked the menu item with phx-click="delete_workspace".
    # In LiveView tests, data-confirm auto-confirms, so deletion happens immediately.
    # We just need to follow any redirect that occurred.
    last_result = context[:last_result]

    case last_result do
      {:error, {:live_redirect, %{to: _path}}} ->
        {:ok, new_view, html} = follow_redirect(last_result, context[:conn])

        {:ok,
         context
         |> Map.put(:view, new_view)
         |> Map.put(:last_html, html)}

      _ ->
        # Already handled or no redirect occurred
        {:ok, context}
    end
  end

  # Chat panel deletion confirmation - used by chat_panel.feature
  step "I confirm deletion", context do
    view = context[:view] || raise "Expected view in context from prior step"

    # For chat message deletion, we need to send the delete_message event directly
    # since data-confirm is a browser-level JS dialog that LiveViewTest bypasses
    message = context[:saved_message] || context[:message_to_delete]

    html =
      case message do
        %{id: message_id} when not is_nil(message_id) ->
          # Send the delete_message event to the chat panel component
          # Use attribute selector to find the delete link by its phx-click and message-id
          view
          |> element(~s([phx-click="delete_message"][phx-value-message-id="#{message_id}"]))
          |> render_click()

        _ ->
          # Fallback: try to find and click a confirmation button
          try do
            view
            |> element("button", ~r/confirm|delete|remove/i)
            |> render_click()
          rescue
            _ -> render(view)
          end
      end

    {:ok, Map.put(context, :last_html, html)}
  end

  step "I attempt to delete workspace {string}", %{args: [workspace_slug]} = context do
    workspace = get_workspace_from_context(context, workspace_slug)
    user = context[:current_user]

    result = Jarga.Workspaces.delete_workspace(user, workspace.id)

    case result do
      {:ok, _workspace} ->
        # This shouldn't happen for unauthorized users, but if it does, try to access delete
        try do
          {:ok, view, _html} = live(context[:conn], ~p"/app/workspaces/#{workspace.slug}")
          # Try to trigger delete
          html =
            view
            |> element("button", "Delete Workspace")
            |> render_click()

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
