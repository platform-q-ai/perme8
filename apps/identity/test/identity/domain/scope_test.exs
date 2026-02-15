defmodule Identity.Domain.ScopeTest do
  @moduledoc """
  Unit tests for the Scope domain module.

  These are pure tests with no database access, testing the scope
  creation and user association logic.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Scope
  alias Identity.Domain.Entities.User
  alias Identity.Domain.Entities.Workspace

  describe "struct" do
    test "has user field defaulting to nil" do
      scope = %Scope{}

      assert scope.user == nil
    end

    test "has workspace field defaulting to nil" do
      scope = %Scope{}

      assert scope.workspace == nil
    end
  end

  describe "for_user/1" do
    test "creates a Scope with the given user" do
      user =
        User.new(%{
          id: "user-123",
          email: "test@example.com"
        })

      scope = Scope.for_user(user)

      assert %Scope{} = scope
      assert scope.user == user
      assert scope.user.id == "user-123"
      assert scope.user.email == "test@example.com"
    end

    test "returns nil when given nil" do
      assert Scope.for_user(nil) == nil
    end

    test "works with any struct that has an id field" do
      # Simulate a different user struct
      other_user = %{
        id: "other-456",
        email: "other@example.com",
        custom_field: "value"
      }

      scope = Scope.for_user(other_user)

      assert %Scope{} = scope
      assert scope.user.id == "other-456"
      assert scope.user.email == "other@example.com"
      assert scope.user.custom_field == "value"
    end

    test "preserves all user fields in scope" do
      user =
        User.new(%{
          id: "user-789",
          first_name: "John",
          last_name: "Doe",
          email: "john@example.com",
          role: "admin",
          status: "active",
          preferences: %{"theme" => "dark"}
        })

      scope = Scope.for_user(user)

      assert scope.user.id == "user-789"
      assert scope.user.first_name == "John"
      assert scope.user.last_name == "Doe"
      assert scope.user.email == "john@example.com"
      assert scope.user.role == "admin"
      assert scope.user.status == "active"
      assert scope.user.preferences == %{"theme" => "dark"}
    end
  end

  describe "for_user_and_workspace/2" do
    test "creates a scope with both user and workspace" do
      user = User.new(%{id: "user-123", email: "test@example.com"})

      workspace =
        Workspace.new(%{id: "ws-123", name: "Test Workspace", slug: "test-workspace"})

      scope = Scope.for_user_and_workspace(user, workspace)

      assert %Scope{} = scope
      assert scope.user == user
      assert scope.workspace == workspace
      assert scope.user.id == "user-123"
      assert scope.workspace.id == "ws-123"
    end

    test "sets workspace alongside user" do
      user = User.new(%{id: "user-456", email: "user@example.com"})
      workspace = Workspace.new(%{id: "ws-456", name: "WS", slug: "ws"})

      scope = Scope.for_user_and_workspace(user, workspace)

      assert scope.user.id == "user-456"
      assert scope.workspace.id == "ws-456"
      assert scope.workspace.name == "WS"
    end
  end

  describe "for_user/1 backward compatibility" do
    test "for_user/1 defaults workspace to nil" do
      user = User.new(%{id: "user-789", email: "test@example.com"})

      scope = Scope.for_user(user)

      assert scope.user == user
      assert scope.workspace == nil
    end
  end

  describe "scope identity" do
    test "two scopes with the same user are equal" do
      user = User.new(%{id: "user-1", email: "a@example.com"})

      scope1 = Scope.for_user(user)
      scope2 = Scope.for_user(user)

      assert scope1 == scope2
    end

    test "two scopes with different users are not equal" do
      user1 = User.new(%{id: "user-1", email: "a@example.com"})
      user2 = User.new(%{id: "user-2", email: "b@example.com"})

      scope1 = Scope.for_user(user1)
      scope2 = Scope.for_user(user2)

      refute scope1 == scope2
    end
  end
end
