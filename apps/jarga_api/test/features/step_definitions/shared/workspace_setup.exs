defmodule JargaApi.Shared.WorkspaceSetupSteps do
  @moduledoc """
  Shared step definitions for workspace test setup.

  These steps are used by workspace, project, API access, and other feature tests
  that need workspace fixtures.

  Adapted for jarga_api: uses JargaApi.ConnCase instead of JargaWeb.ConnCase.
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  import Jarga.WorkspacesFixtures

  alias JargaApi.Test.Helpers

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
    |> Map.put(:workspace_owners, build_workspace_owners(table_data, users))
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp build_workspace_owners(table_data, users) do
    Enum.reduce(table_data, %{}, fn row, acc ->
      slug = row["Slug"]
      owner_email = row["Owner"]
      owner = Map.get(users, owner_email)
      if owner, do: Map.put(acc, slug, owner), else: acc
    end)
  end
end
