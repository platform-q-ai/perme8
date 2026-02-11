defmodule Shared.UserSetupSteps do
  @moduledoc """
  Shared step definitions for user account test setup.

  These steps are used by workspace, project, and other feature tests
  that need user fixtures but aren't specifically testing account functionality.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts
  alias Identity.Infrastructure.Repositories.UserRepository
  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # USER SETUP AND FIXTURES
  # ============================================================================

  step "a user exists with email {string}", %{args: [email]} = context do
    ensure_sandbox_checkout()
    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string}", %{args: [email]} = context do
    ensure_sandbox_checkout()
    user = get_or_create_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    ensure_sandbox_checkout()
    user = get_or_create_user_with_password(email, password)
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "an unconfirmed user exists with email {string}", %{args: [email]} = context do
    ensure_sandbox_checkout()
    user = get_or_create_unconfirmed_user(email)
    {:ok, Map.put(context, :user, user)}
  end

  step "an unconfirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    ensure_sandbox_checkout()
    user = get_or_create_unconfirmed_user_with_password(email, password)
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "the user has no password set", context do
    user = context[:user]
    {:ok, user_updated} = UserRepository.update(user, %{hashed_password: nil})
    {:ok, Map.put(context, :user, user_updated)}
  end

  step "the user has a password set", context do
    user = context[:user]
    user = ensure_password_set(user)
    {:ok, Map.put(context, :user, user)}
  end

  # ============================================================================
  # HELPERS
  # ============================================================================

  defp ensure_sandbox_checkout do
    case Sandbox.checkout(Jarga.Repo) do
      :ok -> Sandbox.mode(Jarga.Repo, {:shared, self()})
      {:already, _owner} -> :ok
    end
  end

  defp ensure_password_set(%{hashed_password: nil} = user) do
    alias Identity.Application.Services.PasswordService
    hashed_password = PasswordService.hash_password("password123!")
    {:ok, updated_user} = UserRepository.update(user, %{hashed_password: hashed_password})
    updated_user
  end

  defp ensure_password_set(user), do: user

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
        set_password_for_user(existing_user, password)
    end
  end

  defp get_or_create_unconfirmed_user(email) do
    case Accounts.get_user_by_email(email) do
      nil ->
        unconfirmed_user_fixture(%{email: email})

      existing_user ->
        reset_user_to_unconfirmed(existing_user)
    end
  end

  defp get_or_create_unconfirmed_user_with_password(email, password) do
    case Accounts.get_user_by_email(email) do
      nil ->
        unconfirmed_user_fixture(%{email: email, password: password})

      existing_user ->
        existing_user
        |> set_password_for_user(password)
        |> reset_user_to_unconfirmed()
    end
  end

  defp reset_user_to_unconfirmed(user) do
    {:ok, updated_user} = UserRepository.update(user, %{confirmed_at: nil})
    updated_user
  end

  defp set_password_for_user(user, password) do
    alias Identity.Application.Services.PasswordService
    hashed_password = PasswordService.hash_password(password)
    {:ok, updated_user} = UserRepository.update(user, %{hashed_password: hashed_password})
    updated_user
  end
end
