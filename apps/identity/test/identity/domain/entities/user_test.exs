defmodule Identity.Domain.Entities.UserTest do
  @moduledoc """
  Unit tests for the User domain entity.

  These are pure tests with no database access, testing the entity's
  value object behavior and business logic.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.User

  describe "new/1" do
    test "creates a User struct with provided attributes" do
      attrs = %{
        id: "user-123",
        first_name: "John",
        last_name: "Doe",
        email: "john@example.com",
        role: "admin",
        status: "active"
      }

      user = User.new(attrs)

      assert %User{} = user
      assert user.id == "user-123"
      assert user.first_name == "John"
      assert user.last_name == "Doe"
      assert user.email == "john@example.com"
      assert user.role == "admin"
      assert user.status == "active"
    end

    test "defaults preferences to empty map" do
      user = User.new(%{email: "test@example.com"})

      assert user.preferences == %{}
    end

    test "allows setting preferences" do
      attrs = %{
        email: "test@example.com",
        preferences: %{"theme" => "dark"}
      }

      user = User.new(attrs)

      assert user.preferences == %{"theme" => "dark"}
    end
  end

  describe "from_schema/1" do
    test "converts a schema-like struct to User entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "user-456",
        first_name: "Jane",
        last_name: "Smith",
        email: "jane@example.com",
        password: nil,
        hashed_password: "hashed123",
        role: "user",
        status: "active",
        avatar_url: "https://example.com/avatar.png",
        confirmed_at: ~U[2024-01-01 12:00:00Z],
        authenticated_at: ~U[2024-01-15 10:00:00Z],
        last_login: ~N[2024-01-15 10:00:00],
        date_created: ~N[2024-01-01 00:00:00],
        preferences: %{"notifications" => true}
      }

      user = User.from_schema(schema)

      assert %User{} = user
      assert user.id == "user-456"
      assert user.first_name == "Jane"
      assert user.last_name == "Smith"
      assert user.email == "jane@example.com"
      assert user.password == nil
      assert user.hashed_password == "hashed123"
      assert user.role == "user"
      assert user.status == "active"
      assert user.avatar_url == "https://example.com/avatar.png"
      assert user.confirmed_at == ~U[2024-01-01 12:00:00Z]
      assert user.authenticated_at == ~U[2024-01-15 10:00:00Z]
      assert user.last_login == ~N[2024-01-15 10:00:00]
      assert user.date_created == ~N[2024-01-01 00:00:00]
      assert user.preferences == %{"notifications" => true}
    end

    test "defaults preferences to empty map when nil in schema" do
      schema = %{
        __struct__: SomeSchema,
        id: "user-789",
        first_name: nil,
        last_name: nil,
        email: "test@example.com",
        password: nil,
        hashed_password: nil,
        role: nil,
        status: nil,
        avatar_url: nil,
        confirmed_at: nil,
        authenticated_at: nil,
        last_login: nil,
        date_created: nil,
        preferences: nil
      }

      user = User.from_schema(schema)

      assert user.preferences == %{}
    end
  end

  describe "valid_password?/2" do
    test "returns true for valid password" do
      # Hash a known password for testing
      hashed = Bcrypt.hash_pwd_salt("correct_password")
      user = User.new(%{email: "test@example.com", hashed_password: hashed})

      assert User.valid_password?(user, "correct_password") == true
    end

    test "returns false for invalid password" do
      hashed = Bcrypt.hash_pwd_salt("correct_password")
      user = User.new(%{email: "test@example.com", hashed_password: hashed})

      assert User.valid_password?(user, "wrong_password") == false
    end

    test "returns false for empty password" do
      hashed = Bcrypt.hash_pwd_salt("correct_password")
      user = User.new(%{email: "test@example.com", hashed_password: hashed})

      assert User.valid_password?(user, "") == false
    end

    test "returns false when user has no hashed_password" do
      user = User.new(%{email: "test@example.com", hashed_password: nil})

      assert User.valid_password?(user, "any_password") == false
    end

    test "returns false for nil user" do
      assert User.valid_password?(nil, "any_password") == false
    end
  end

  describe "Inspect protocol" do
    test "redacts password field" do
      user = User.new(%{email: "test@example.com", password: "secret123"})

      inspected = inspect(user)

      assert inspected =~ "**redacted**"
      refute inspected =~ "secret123"
    end

    test "redacts hashed_password field" do
      user = User.new(%{email: "test@example.com", hashed_password: "$2b$12$hash..."})

      inspected = inspect(user)

      assert inspected =~ "**redacted**"
      refute inspected =~ "$2b$12$hash..."
    end

    test "shows nil for nil password fields" do
      user = User.new(%{email: "test@example.com"})

      inspected = inspect(user)

      # Should show the struct with nil values, not redacted
      assert inspected =~ "Identity.Domain.Entities.User"
    end
  end
end
