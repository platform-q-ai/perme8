defmodule Jarga.Accounts.Domain.ScopeTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Scope
  alias Jarga.Accounts.Domain.Entities.User

  describe "for_user/1" do
    test "creates a scope with the given user" do
      user = %User{
        id: Ecto.UUID.generate(),
        email: "test@example.com",
        confirmed_at: ~U[2024-01-01 00:00:00Z]
      }

      scope = Scope.for_user(user)

      assert %Scope{} = scope
      assert scope.user == user
      assert scope.user.email == "test@example.com"
    end

    test "returns nil when given nil user" do
      assert Scope.for_user(nil) == nil
    end

    test "struct can hold user information" do
      user = %User{
        id: Ecto.UUID.generate(),
        email: "admin@example.com",
        confirmed_at: ~U[2024-01-01 00:00:00Z]
      }

      scope = %Scope{user: user}

      assert scope.user.id == user.id
      assert scope.user.email == "admin@example.com"
    end
  end
end
