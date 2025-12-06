defmodule Workspaces.MembersSteps do
  @moduledoc """
  Step definitions for workspace member management scenarios.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures

  alias Jarga.Workspaces

  # ============================================================================
  # MEMBER MANAGEMENT STEPS
  # ============================================================================

  step "I invite {string} as {string} to workspace {string}",
       %{args: [email, role, _workspace_slug]} = context do
    # First, check if the members modal is open. If not, open it
    html = context[:last_html] || raise "No HTML. Navigate to a page first."
    view = context[:view] || raise "No view. Navigate to a page first."

    # Check if modal is already open, if not open it
    modal_already_open =
      String.contains?(html, "modal-open") and String.contains?(html, "invite-form")

    view_with_modal =
      case modal_already_open do
        true ->
          # Modal is already open
          view

        false ->
          # Open the modal first
          view
          |> element("button", "Manage Members")
          |> render_click()

          view
      end

    # Submit the invite form - this will trigger a flash message
    _submit_html =
      view_with_modal
      |> form("#invite-form", %{"email" => email, "role" => role})
      |> render_submit()

    # Close the modal to see the flash message (click the Done button)
    html =
      view
      |> element("button.btn-neutral", "Done")
      |> render_click()

    # The flash message should now be in the HTML
    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:ok, :invitation_sent})}
  end

  step "I invite {string} as {string}", %{args: [email, role]} = context do
    # Use the LiveView to submit the invite form
    view = context[:view]

    # Submit the form - this sets the flash AND reloads members list
    html =
      view
      |> form("#invite-form", %{"email" => email, "role" => role})
      |> render_submit()

    # The modal is still open with updated members list
    # Flash message is in socket but we'll check member list in modal
    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:view, view)
     |> Map.put(:last_result, {:ok, :invitation_sent})}
  end

  step "I change {string}'s role to {string}", %{args: [email, new_role]} = context do
    # Use the LiveView to trigger role change event
    view = context[:view]

    html =
      view
      |> element("select[phx-change='change_role'][phx-value-email='#{email}']")
      |> render_change(%{"email" => email, "value" => new_role})

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:ok, :role_changed})}
  end

  step "I remove {string} from workspace", %{args: [email]} = context do
    workspace = context[:workspace]
    user = context[:current_user]

    result = Workspaces.remove_member(user, workspace.id, email)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I remove {string} from the workspace", %{args: [email]} = context do
    # Use the LiveView to trigger remove member event
    view = context[:view]

    html =
      view
      |> element("button[phx-click='remove_member'][phx-value-email='#{email}']")
      |> render_click()

    {:ok,
     context
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:ok, :member_removed})}
  end

  step "I attempt to invite {string} as {string} to workspace {string}",
       %{args: [email, role, workspace_slug]} = context do
    workspace = get_workspace_from_context(context, workspace_slug)
    user = context[:current_user]
    role_atom = String.to_existing_atom(role)

    result = Workspaces.invite_member(user, workspace.id, email, role_atom)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I attempt to change {string}'s role", %{args: [email]} = context do
    # This step is used when UI doesn't allow role changes
    workspace = context[:workspace]
    user = context[:current_user]

    # Try to change role (should fail)
    result = Workspaces.change_member_role(user, workspace.id, email, :admin)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I attempt to remove {string} from workspace", %{args: [email]} = context do
    workspace = context[:workspace]
    user = context[:current_user]

    result = Workspaces.remove_member(user, workspace.id, email)

    {:ok, Map.put(context, :last_result, result)}
  end

  step "I attempt to remove {string} from the workspace", %{args: [email]} = context do
    # First check if remove button exists in the UI
    html = context[:last_html] || raise "No HTML. Navigate to a page first."
    view = context[:view] || raise "No view. Navigate to a page first."

    # Check if the remove button exists for this user
    button_exists =
      html =~ ~r/phx-click="remove_member".*phx-value-email="#{Regex.escape(email)}"/s

    case button_exists do
      true ->
        # Button exists, try to click it via LiveView
        html =
          view
          |> element("button[phx-click='remove_member'][phx-value-email='#{email}']")
          |> render_click()

        {:ok,
         context
         |> Map.put(:last_html, html)
         |> Map.put(:last_result, {:ok, :member_removed})}

      false ->
        # Button doesn't exist (e.g., trying to remove owner)
        # Try via backend to get the actual error
        workspace = context[:workspace] || raise "No workspace. Set :workspace in a prior step."
        user = context[:current_user] || raise "No user. Run 'Given I am logged in' first."

        result = Workspaces.remove_member(user, workspace.id, email)

        {:ok, Map.put(context, :last_result, result)}
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
