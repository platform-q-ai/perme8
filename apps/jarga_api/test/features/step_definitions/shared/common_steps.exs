defmodule JargaApi.CommonSteps do
  @moduledoc """
  Common step definitions shared across all Cucumber features in jarga_api.

  Adapted for API context: "I am logged in as" sets context[:current_user]
  without session login (API uses Bearer token auth, not sessions).
  """

  use Cucumber.StepDefinition
  use JargaApi.ConnCase, async: false

  import Phoenix.ConnTest
  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias JargaApi.Test.Helpers

  # ============================================================================
  # AUTHENTICATION STEPS
  # ============================================================================

  step "I am logged in as {string}", %{args: [email]} = context do
    user = require_user!(context, email)

    # For API tests, we just set the current_user in context.
    # API auth uses Bearer tokens, not session cookies.
    {:ok,
     context
     |> Map.put(:conn, build_conn())
     |> Map.put(:current_user, user)}
  end

  # ============================================================================
  # MEMBERSHIP STEPS
  # ============================================================================

  step "{string} is a member of workspace {string}", %{args: [email, workspace_slug]} = context do
    user = require_user!(context, email)
    workspace = require_workspace!(context, workspace_slug)

    # Add as member, ignoring if already a member (e.g., as owner)
    try do
      add_workspace_member_fixture(workspace.id, user, :member)
    rescue
      Ecto.ConstraintError -> :ok
      Ecto.InvalidChangesetError -> :ok
    end

    {:ok, context}
  end

  # ============================================================================
  # WORKSPACE SHORTHAND STEPS
  # ============================================================================

  step "a workspace {string} exists", %{args: [name]} = context do
    Helpers.ensure_sandbox_checkout()

    slug = name |> String.downcase() |> String.replace(~r/\s+/, "-")
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})
    workspace = workspace_fixture(owner, %{name: name, slug: slug})

    workspaces = Map.get(context, :workspaces, %{})

    {:ok,
     context
     |> Map.put(:workspaces, Map.put(workspaces, name, workspace))
     |> Map.put(:workspace_owners, Map.put(Map.get(context, :workspace_owners, %{}), name, owner))}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp require_user!(context, email) do
    get_in(context, [:users, email]) ||
      raise "User #{email} not found in context[:users]. Make sure 'the following users exist:' step ran first."
  end

  defp require_workspace!(context, workspace_slug) do
    workspaces = context[:workspaces] || %{}

    Map.get(workspaces, workspace_slug) ||
      raise "Workspace #{workspace_slug} not found in context[:workspaces]"
  end
end
