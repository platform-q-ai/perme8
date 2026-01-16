defmodule Jarga.TestUsers do
  @moduledoc """
  Module for managing persistent test users across E2E test suites.

  This module provides functions to create and retrieve test users that persist
  across multiple test runs. This is useful for E2E tests that require authenticated
  users without needing to create new users for every test.

  ## Usage

      # In test_helper.exs or test setup
      Jarga.TestUsers.ensure_test_users_exist()

      # In tests
      user = Jarga.TestUsers.get_user(:alice)
      session |> log_in_user(user)

  ## Available Test Users

  - `:alice` - Admin user (alice@example.com)
  - `:bob` - Regular member (bob@example.com)
  - `:charlie` - Guest user (charlie@example.com)
  """

  # Test utility module - top-level boundary
  use Boundary,
    top_level?: true,
    deps: [Jarga.Repo, Jarga.Accounts],
    exports: []

  alias Jarga.Accounts
  alias Jarga.Accounts.Domain.Entities.User
  alias Jarga.Accounts.Infrastructure.Schemas.UserSchema
  alias Jarga.Repo

  @test_users %{
    alice: %{
      email: "alice@example.com",
      password: "TestPassword123!",
      first_name: "Alice",
      last_name: "Anderson",
      role: :admin
    },
    bob: %{
      email: "bob@example.com",
      password: "TestPassword123!",
      first_name: "Bob",
      last_name: "Builder",
      role: :member
    },
    charlie: %{
      email: "charlie@example.com",
      password: "TestPassword123!",
      first_name: "Charlie",
      last_name: "Chen",
      role: :guest
    }
  }

  @doc """
  Returns the map of all defined test users.
  """
  def test_users, do: @test_users

  @doc """
  Ensures all test users exist in the database.

  This function is idempotent - it will only create users that don't already exist.
  Should be called once in test_helper.exs or in test setup.

  ## Examples

      # In test_helper.exs
      Jarga.TestUsers.ensure_test_users_exist()

  """
  def ensure_test_users_exist do
    Enum.each(@test_users, fn {key, attrs} ->
      case Repo.get_by(UserSchema, email: attrs.email) do
        nil -> create_test_user(key, attrs)
        _user -> :ok
      end
    end)
  end

  @doc """
  Gets a test user by their key.

  Returns the user struct if found, raises if not found.

  ## Examples

      user = Jarga.TestUsers.get_user(:alice)
      user = Jarga.TestUsers.get_user(:bob)

  """
  def get_user(key) when is_atom(key) do
    attrs = Map.fetch!(@test_users, key)

    case Repo.get_by(UserSchema, email: attrs.email) do
      nil ->
        raise "Test user #{key} (#{attrs.email}) not found. Did you call ensure_test_users_exist/0?"

      user_schema ->
        User.from_schema(user_schema)
    end
  end

  @doc """
  Gets the password for a test user.

  ## Examples

      password = Jarga.TestUsers.get_password(:alice)
      # => "TestPassword123!"

  """
  def get_password(key) when is_atom(key) do
    attrs = Map.fetch!(@test_users, key)
    attrs.password
  end

  @doc """
  Gets all available test user keys.

  ## Examples

      Jarga.TestUsers.list_user_keys()
      # => [:alice, :bob, :charlie]

  """
  def list_user_keys do
    Map.keys(@test_users)
  end

  @doc """
  Clears all test users from the database.

  Useful for cleanup between test suites or in teardown.

  ## Examples

      Jarga.TestUsers.clear_test_users()

  """
  def clear_test_users do
    Enum.each(@test_users, fn {_key, attrs} ->
      case Repo.get_by(UserSchema, email: attrs.email) do
        nil -> :ok
        user_schema -> Repo.delete(user_schema)
      end
    end)
  end

  ## Private Functions

  defp create_test_user(_key, attrs) do
    {:ok, user} =
      Accounts.register_user(%{
        email: attrs.email,
        password: attrs.password,
        first_name: attrs.first_name,
        last_name: attrs.last_name
      })

    # Confirm users immediately so they can log in (bypassing email confirmation)
    # Convert domain User to UserSchema, update, then discard (return :ok)
    user
    |> UserSchema.to_schema()
    |> Ecto.Changeset.change(%{confirmed_at: DateTime.utc_now() |> DateTime.truncate(:second)})
    |> Repo.update!()

    :ok
  end
end
