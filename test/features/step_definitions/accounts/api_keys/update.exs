defmodule Accounts.ApiKeys.UpdateSteps do
  @moduledoc """
  Step definitions for API Key update and revocation operations.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.Test.StepHelpers

  alias Jarga.Accounts.ApiKeys.Helpers

  # ============================================================================
  # API KEY REVOCATION STEPS
  # ============================================================================

  step "I revoke the API key {string}", %{args: [name]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")
    user = context[:current_user]

    api_key = Helpers.fetch_api_key_by_name(user.id, name)
    assert api_key != nil, "Expected to find API key '#{name}'"

    html = Helpers.click_revoke_button(view, api_key.id)
    revoked_key = Helpers.fetch_api_key_by_id(user.id, api_key.id)

    result =
      if (Helpers.revocation_successful?(html) and revoked_key) && !revoked_key.is_active do
        {:ok, revoked_key}
      else
        {:error, :revocation_failed}
      end

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, result)
     |> Map.put(:revoked_api_key, revoked_key)}
  end

  step "I attempt to revoke the API key {string}", %{args: [name]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    other_api_key = context[:other_api_key]
    assert other_api_key != nil, "Expected other_api_key to be set in context"
    assert other_api_key.name == name, "Expected other_api_key name to match '#{name}'"

    html = render(view)

    # Security check: another user's API key button should NOT be visible
    # This is the expected behavior - users cannot see/revoke other users' keys
    has_other_users_button = html =~ "phx-value-id=\"#{other_api_key.id}\""
    refute has_other_users_button, "Security violation: other user's API key button is visible"

    # Since button is not visible, the action is forbidden
    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, {:error, :forbidden})}
  end

  # ============================================================================
  # API KEY UPDATE STEPS
  # ============================================================================

  step "I update the API key {string} to have access to {string}",
       %{args: [name, workspace_access_str]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")
    user = context[:current_user]

    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    api_key = Helpers.fetch_api_key_by_name(user.id, name)
    assert api_key, "Expected to find API key '#{name}'"

    Helpers.click_edit_button(view, api_key.id)

    # Toggle workspace checkboxes to match desired workspace_access
    toggle_workspace_checkboxes(view, api_key.workspace_access, workspace_access)

    html = Helpers.submit_edit_form(view)
    context = build_update_result(context, html, name, api_key.id)

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end

  step "I update the API key with the following details:", context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    table_data = context.datatable.maps
    row = List.first(table_data)
    new_name = row["Name"]

    api_key = context[:api_key]
    assert api_key, "Expected api_key struct in context"

    Helpers.click_edit_button(view, api_key.id)

    form_data = %{name: new_name, description: row["Description"]}
    html = Helpers.submit_edit_form(view, form_data)

    context = build_update_result(context, html, new_name, api_key.id)
    context = Map.put(context, :api_key_name, new_name)

    # Return context directly for data table steps
    context
    |> Map.put(:view, view)
    |> Map.put(:last_html, html)
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp toggle_workspace_checkboxes(view, current_workspaces, desired_workspaces) do
    to_add = desired_workspaces -- current_workspaces
    to_remove = current_workspaces -- desired_workspaces

    Enum.each(to_remove, fn ws ->
      view
      |> element("input[type='checkbox'][name='workspace_access[]'][value='#{ws}']")
      |> render_click()
    end)

    Enum.each(to_add, fn ws ->
      view
      |> element("input[type='checkbox'][name='workspace_access[]'][value='#{ws}']")
      |> render_click()
    end)
  end

  defp build_update_result(context, html, name, api_key_id) do
    user = context[:current_user]

    if Helpers.creation_successful?(html, name) do
      context
      |> Map.put(:api_key, Helpers.fetch_api_key_by_id(user.id, api_key_id))
      |> Map.put(:last_result, :ok)
    else
      Map.put(context, :last_result, {:error, :update_failed})
    end
  end
end
