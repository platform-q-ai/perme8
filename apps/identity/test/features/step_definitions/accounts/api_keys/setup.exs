defmodule Identity.Accounts.ApiKeys.SetupSteps do
  @moduledoc """
  Setup step definitions for API Key Management feature tests.

  These steps create test fixtures (workspaces, API keys) for scenarios.

  NOTE: Uses Jarga.Accounts for domain operations to ensure consistent entity types.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest
  import Jarga.WorkspacesFixtures

  alias Jarga.Accounts
  alias Identity.Accounts.ApiKeys.Helpers
  alias Identity.Infrastructure.Repositories.ApiKeyRepository

  # ============================================================================
  # WORKSPACE SETUP STEPS
  # ============================================================================

  step "the following workspaces exist:", context do
    Helpers.ensure_sandbox_checkout()

    table_data = context.datatable.maps
    users = context[:users] || %{}

    workspaces =
      Enum.reduce(table_data, %{}, fn row, acc ->
        name = row["Name"]
        requested_slug = row["Slug"]
        owner_email = row["Owner"]

        owner = Map.get(users, owner_email) || raise "Owner #{owner_email} not found in users"

        workspace = workspace_fixture(owner, %{name: name, slug: requested_slug})

        # Store by REQUESTED slug (from feature file) so step definitions can look up
        # by the feature file's slug. This works because each scenario runs in its
        # own sandbox transaction, so slug conflicts only happen within the same scenario.
        Map.put(acc, requested_slug, workspace)
      end)

    # Return context directly for data table steps
    context
    |> Map.put(:workspaces, workspaces)
    |> Map.put(:workspace_owners, Helpers.build_workspace_owners(table_data, users))
  end

  # ============================================================================
  # API KEY FIXTURE STEPS
  # ============================================================================

  step "I have the following API keys:", context do
    user = context[:current_user]
    table_data = context.datatable.maps

    # Delete all existing API keys for this user to ensure clean state
    delete_all_api_keys_for_user(user.id)

    api_keys =
      Enum.map(table_data, fn row ->
        name = row["Name"]
        workspace_access_str = row["Workspace Access"]

        workspace_access = Helpers.parse_workspace_access(workspace_access_str)

        attrs = %{
          name: name,
          description: nil,
          workspace_access: workspace_access
        }

        {:ok, {api_key, _token}} = Accounts.create_api_key(user.id, attrs)
        api_key
      end)

    # Return context directly for data table steps
    Map.put(context, :api_keys, api_keys)
  end

  # Delete all API keys for a user (test cleanup helper)
  defp delete_all_api_keys_for_user(user_id) do
    ApiKeyRepository.delete_by_user_id(Identity.Repo, user_id)
  end

  step "I have an API key named {string}", %{args: [name]} = context do
    user = context[:current_user]

    attrs = %{
      name: name,
      description: nil,
      workspace_access: []
    }

    {:ok, {api_key, _token}} = Accounts.create_api_key(user.id, attrs)

    {:ok, Map.put(context, :api_key, api_key)}
  end

  step "I have an API key named {string} with access to {string}",
       %{args: [name, workspace_access_str]} = context do
    user = context[:current_user]

    workspace_access = Helpers.parse_workspace_access(workspace_access_str)

    attrs = %{
      name: name,
      description: nil,
      workspace_access: workspace_access
    }

    {:ok, {api_key, _token}} = Accounts.create_api_key(user.id, attrs)

    {:ok, Map.put(context, :api_key, api_key)}
  end

  step "{string} has an API key named {string}", %{args: [email, name]} = context do
    user = get_in(context, [:users, email]) || raise "User #{email} not found"

    attrs = %{
      name: name,
      description: nil,
      workspace_access: []
    }

    {:ok, {api_key, _token}} = Accounts.create_api_key(user.id, attrs)

    {:ok, Map.put(context, :other_api_key, api_key)}
  end

  # ============================================================================
  # NAVIGATION STEPS
  # ============================================================================

  step "I view my API keys", context do
    conn = context[:conn]

    # Full-stack test: render the LiveView
    {:ok, view, html} = live(conn, ~p"/users/settings/api-keys")

    {:ok,
     context
     |> Map.put(:view, view)
     |> Map.put(:last_html, html)}
  end
end
