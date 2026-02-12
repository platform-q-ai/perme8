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

  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # AUTHENTICATION STEPS
  # ============================================================================

  step "I am logged in as {string}", %{args: [email]} = context do
    user = get_in(context, [:users, email])

    unless user do
      raise "User #{email} not found in context[:users]. Make sure 'the following users exist:' step ran first."
    end

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
    user = get_in(context, [:users, email])

    unless user do
      raise "User #{email} not found in context[:users]"
    end

    workspaces = context[:workspaces] || %{}
    workspace = Map.get(workspaces, workspace_slug)

    unless workspace do
      raise "Workspace #{workspace_slug} not found in context[:workspaces]"
    end

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
    ensure_sandbox_checkout()

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

  defp ensure_sandbox_checkout do
    case Sandbox.checkout(Jarga.Repo) do
      :ok -> Sandbox.mode(Jarga.Repo, {:shared, self()})
      {:already, _owner} -> :ok
    end

    case Sandbox.checkout(Identity.Repo) do
      :ok -> Sandbox.mode(Identity.Repo, {:shared, self()})
      {:already, _owner} -> :ok
    end
  end
end
