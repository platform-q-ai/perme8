defmodule Accounts.SetupSteps do
  @moduledoc """
  Step definitions for user account test setup and fixtures.
  """

  use Cucumber.StepDefinition
  use JargaWeb.ConnCase, async: false

  import Jarga.AccountsFixtures

  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Repo
  alias Ecto.Adapters.SQL.Sandbox

  # ============================================================================
  # USER SETUP AND FIXTURES
  # ============================================================================

  step "a user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = user_fixture(%{email: email})
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = user_fixture(%{email: email})
    {:ok, Map.put(context, :user, user)}
  end

  step "a confirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = user_fixture(%{email: email, password: password})
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "an unconfirmed user exists with email {string}", %{args: [email]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = unconfirmed_user_fixture(%{email: email})
    {:ok, Map.put(context, :user, user)}
  end

  step "an unconfirmed user exists with email {string} and password {string}",
       %{args: [email, password]} = context do
    # Ensure sandbox is checked out
    case Sandbox.checkout(Jarga.Repo) do
      :ok ->
        Sandbox.mode(Jarga.Repo, {:shared, self()})

      {:already, _owner} ->
        :ok
    end

    user = unconfirmed_user_fixture(%{email: email, password: password})
    {:ok, Map.put(context, :user, user) |> Map.put(:password, password)}
  end

  step "the user has no password set", context do
    user = context[:user]

    # Remove password by setting hashed_password to nil
    user_updated_schema =
      user
      |> UserSchema.to_schema()
      |> Ecto.Changeset.change(hashed_password: nil)
      |> Repo.update!()

    user_updated = User.from_schema(user_updated_schema)

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
end
