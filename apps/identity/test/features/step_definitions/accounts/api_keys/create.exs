defmodule Identity.Accounts.ApiKeys.CreateSteps do
  @moduledoc """
  Step definitions for API Key creation operations.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Phoenix.LiveViewTest
  import Jarga.Test.StepHelpers

  alias Identity.Accounts.ApiKeys.Helpers

  # ============================================================================
  # API KEY CREATION STEPS
  # ============================================================================

  step "I create an API key with the following details:", context do
    table_data = context.datatable.maps
    row = List.first(table_data)

    name = row["Name"]
    description = row["Description"]
    workspace_access = Helpers.parse_workspace_access(row["Workspace Access"])

    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    Helpers.click_create_button(view)

    form_data = %{name: name, description: description || "", workspace_access: workspace_access}
    html = Helpers.submit_create_form(view, form_data)

    context = build_creation_result(context, html, name)

    # Return context directly for data table steps
    Map.put(context, :view, view)
  end

  step "I create an API key with name {string}", %{args: [name]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    Helpers.click_create_button(view)

    form_data = %{name: name, description: "", workspace_access: []}
    html = Helpers.submit_create_form(view, form_data)

    context = build_creation_result(context, html, name)

    {:ok, Map.put(context, :view, view)}
  end

  step "I attempt to create an API key with access to workspace {string}",
       %{args: [workspace_slug]} = context do
    {view, context} = ensure_view(context, ~p"/users/settings/api-keys")

    Helpers.click_create_button(view)

    html = render(view)

    # The UI should NOT show a checkbox for a workspace the user doesn't have access to
    has_workspace_option? = html =~ "value=\"#{workspace_slug}\""

    result =
      if has_workspace_option? do
        form_data = %{name: "Test Key", description: "Test", workspace_access: [workspace_slug]}
        submit_html = Helpers.submit_create_form(view, form_data)

        if submit_html =~ "don't have access" or submit_html =~ "forbidden" do
          {:error, :forbidden}
        else
          :ok
        end
      else
        # Workspace not available in UI = forbidden by design
        {:error, :forbidden}
      end

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)
     |> Map.put(:last_result, result)
     |> Map.put(:api_key, nil)}
  end

  # ============================================================================
  # PRIVATE HELPERS
  # ============================================================================

  defp build_creation_result(context, html, name) do
    user = context[:current_user]
    success? = Helpers.creation_successful?(html, name)

    if success? do
      context
      |> Map.put(:last_html, html)
      |> Map.put(:plain_token, Helpers.extract_token_from_html(html))
      |> Map.put(:api_key, Helpers.fetch_api_key_by_name(user.id, name))
      |> Map.put(:last_result, :ok)
    else
      context
      |> Map.put(:last_html, html)
      |> Map.put(:last_result, {:error, :creation_failed})
    end
  end
end
