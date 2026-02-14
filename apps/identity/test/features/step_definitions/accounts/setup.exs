defmodule Identity.Accounts.SetupSteps do
  @moduledoc """
  Step definitions for user account test setup and fixtures.

  NOTE: These step definitions use Jarga.Accounts instead of Identity to ensure
  consistent domain entity types. The Identity facade returns Identity.Domain.Entities.User,
  but the infrastructure repositories expect Jarga.Accounts.Domain.Entities.User.
  Using Jarga.Accounts ensures all functions receive the correct entity type.
  """

  use Cucumber.StepDefinition
  use IdentityWeb.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts
  alias Identity.Infrastructure.Repositories.UserRepository
  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # USER SETUP AND FIXTURES
  # ============================================================================

  step "a user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out for both repos
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = get_or_create_user_with_password(email, password)
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "an unconfirmed user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = get_or_create_unconfirmed_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "an unconfirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = get_or_create_unconfirmed_user_with_password(email, password)
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "the user has no password set", context do
    user = context[:user]

    # Remove password by setting hashed_password to nil
    {:ok, user_updated} = UserRepository.update(user, %{hashed_password: nil})

    {:ok, Map.put(context, :user, user_updated)}
  end

  step "the user has a password set", context do
    user = context[:user]
    # User should already have password from fixture - verify and ensure it
    user = ensure_password_set(user)
    {:ok, Map.put(context, :user, user)}
  end

  # Helper to ensure user has password set (unconditionally)
  defp ensure_password_set(%{hashed_password: nil} = user), do: set_password(user)
  defp ensure_password_set(user), do: user

  # Get existing user or create a new one (idempotent)
  defp get_or_create_user(email) do
    case Accounts.get_user_by_email(email) do
      nil -> user_fixture(%{email: email})
      existing_user -> existing_user
    end
  end

  defp get_or_create_user_with_password(email, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        user_fixture(%{email: email, password: password})

      existing_user ->
        # Ensure the password is set for existing user
        set_password_for_user(existing_user, password)
    end
  end

  defp get_or_create_unconfirmed_user(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        unconfirmed_user_fixture(%{email: email})

      existing_user ->
        # Reset confirmed_at to nil for unconfirmed user scenarios
        reset_user_to_unconfirmed(existing_user)
    end
  end

  defp get_or_create_unconfirmed_user_with_password(email, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        unconfirmed_user_fixture(%{email: email, password: password})

      existing_user ->
        # Ensure the password is set and user is unconfirmed
        existing_user
        |> set_password_for_user(password)
        |> reset_user_to_unconfirmed()
    end
  end

  # Reset user to unconfirmed state
  defp reset_user_to_unconfirmed(user) do
    {:ok, updated_user} = UserRepository.update(user, %{confirmed_at: nil})
    updated_user
  end

  # Set a specific password for a user
  defp set_password_for_user(user, password) do
    alias Identity.Application.Services.PasswordService

    hashed_password = PasswordService.hash_password(password)

    {:ok, updated_user} = UserRepository.update(user, %{hashed_password: hashed_password})
    updated_user
  end

  # ============================================================================
  # MULTIPLE USERS SETUP (for Background sections)
  # ============================================================================

  step "the following users exist:", context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Identity.Repo) do
      :ok ->
        Sandbox.mode(Identity.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    table_data = context.datatable.maps

    users =
      Enum.reduce(table_data, %{}, fn row, acc ->
        email = row["Email"]
        name = row["Name"]
        [first_name, last_name] = String.split(name, " ", parts: 2)

        user = get_or_create_user_with_name(email, first_name, last_name)
        Map.put(acc, email, user)
      end)

    # Return context directly for data table steps
    Map.put(context, :users, users)
  end

  defp get_or_create_user_with_name(email, first_name, last_name) do
    case Accounts.get_user_by_email(email) do
      nil ->
        user_fixture(%{email: email, first_name: first_name, last_name: last_name})

      existing_user ->
        existing_user
    end
  end

  # ============================================================================
  # WORKSPACE MEMBERSHIP SETUP
  # ============================================================================

  step "{string} is a member of workspace {string}", %{args: [email, workspace_slug]} = context do
    users = context[:users] || %{}
    workspaces = context[:workspaces] || %{}

    user = Map.get(users, email) || raise "User #{email} not found in users"

    workspace =
      Map.get(workspaces, workspace_slug) || raise "Workspace #{workspace_slug} not found"

    # Add user as member if not already
    alias Identity.Infrastructure.Repositories.MembershipRepository

    unless MembershipRepository.member?(user.id, workspace.id) do
      import Jarga.WorkspacesFixtures
      add_workspace_member_fixture(workspace.id, user, :member)
    end

    {:ok, context}
  end
end
