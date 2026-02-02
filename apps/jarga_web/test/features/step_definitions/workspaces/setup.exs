defmodule Workspaces.SetupSteps do
  @moduledoc """
  Step definitions for workspace test setup and fixtures.

  These steps create workspaces and users in various states for testing.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  alias Ecto.Adapters.SQL.Sandbox
  alias Jarga.Accounts

  # ============================================================================
  # DATA TABLE STEPS
  # ============================================================================

  step "the following users exist:", context do
    # Ensure sandbox is in shared mode for API tests
    ensure_shared_sandbox_mode()

    # Access data table using dot notation
    table_data = context.datatable.maps
    workspace = context[:workspace]

    users =
      Enum.reduce(table_data, %{}, fn row, acc ->
        user = create_user_from_row(row)
        maybe_add_to_workspace(workspace, user, row["Role"])
        Map.put(acc, row["Email"], user)
      end)

    # Return context directly (no {:ok, }) for data table steps
    Map.put(context, :users, users)
  end

  defp ensure_shared_sandbox_mode do
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        # Already checked out, but ensure shared mode is set
        Sandbox.mode(Jarga.Repo, {:shared, self()})
    end
  end

  defp create_user_from_row(row) do
    email = row["Email"]

    # Check if user already exists (for idempotent tests)
    case Accounts.get_user_by_email(email) do
      nil ->
        attrs = %{email: email}
        attrs = maybe_add_name(attrs, row["Name"])
        user_fixture(attrs)

      existing_user ->
        existing_user
    end
  end

  defp maybe_add_name(attrs, nil), do: attrs
  defp maybe_add_name(attrs, name), do: Map.put(attrs, :name, name)

  defp maybe_add_to_workspace(nil, _user, _role), do: :ok
  defp maybe_add_to_workspace(_workspace, _user, nil), do: :ok

  defp maybe_add_to_workspace(workspace, user, role) do
    add_workspace_member_fixture(workspace.id, user, String.to_existing_atom(role))
  end

  # ============================================================================
  # USER FIXTURE STEPS
  # ============================================================================

  step "a user {string} exists but is not a member of any workspace",
       %{args: [email]} = context do
    # Check if user already exists in context
    users = Map.get(context, :users, %{})

    user =
      case Map.get(users, email) do
        nil ->
          # Only create user if not already exists
          user_fixture(%{email: email})

        existing_user ->
          existing_user
      end

    {:ok, Map.put(context, :users, Map.put(users, email, user))}
  end

  # ============================================================================
  # WORKSPACE FIXTURE STEPS
  # ============================================================================

  step "a workspace exists with name {string} and slug {string} and color {string}",
       %{args: [name, slug, color]} = context do
    # Only checkout sandbox if not already checked out
    case context[:workspace] do
      nil ->
        case Sandbox.checkout(Jarga.Repo) do
          :ok ->
            Sandbox.mode(Jarga.Repo, {:shared, self()})

          {:already, _owner} ->
            :ok
        end

      _ ->
        :ok
    end

    # Create owner user for workspace
    owner = user_fixture(%{email: "#{slug}_owner@example.com"})

    workspace = workspace_fixture(owner, %{name: name, slug: slug, color: color})

    # Store as additional workspace
    additional_workspaces = Map.get(context, :additional_workspaces, %{})

    {:ok,
     context
     |> Map.put(:additional_workspaces, Map.put(additional_workspaces, slug, workspace))
     |> Map.put(
       :additional_owners,
       Map.put(Map.get(context, :additional_owners, %{}), slug, owner)
     )}
  end

  # ============================================================================
  # HELPER FUNCTIONS
  # ============================================================================

  def get_workspace_from_context(context, "product-team") do
    context[:workspace]
  end

  def get_workspace_from_context(context, "Dev Team") do
    context[:workspace] || context[:current_workspace]
  end

  def get_workspace_from_context(context, "QA Team") do
    # Look for QA Team in workspaces map or create it
    find_or_create_workspace(context, "qa-team", "QA Team")
  end

  def get_workspace_from_context(context, slug) when is_binary(slug) do
    # Look in workspaces map first, then additional_workspaces
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
