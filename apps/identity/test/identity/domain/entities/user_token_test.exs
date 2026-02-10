defmodule Identity.Domain.Entities.UserTokenTest do
  @moduledoc """
  Unit tests for the UserToken domain entity.

  These are pure tests with no database access, testing the entity's
  value object behavior and schema conversion.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.UserToken

  describe "struct" do
    test "has expected fields" do
      token = %UserToken{}

      assert Map.has_key?(token, :id)
      assert Map.has_key?(token, :token)
      assert Map.has_key?(token, :context)
      assert Map.has_key?(token, :sent_to)
      assert Map.has_key?(token, :authenticated_at)
      assert Map.has_key?(token, :user_id)
      assert Map.has_key?(token, :inserted_at)
    end

    test "all fields default to nil" do
      token = %UserToken{}

      assert token.id == nil
      assert token.token == nil
      assert token.context == nil
      assert token.sent_to == nil
      assert token.authenticated_at == nil
      assert token.user_id == nil
      assert token.inserted_at == nil
    end
  end

  describe "from_schema/1" do
    test "converts a schema-like map to UserToken entity" do
      now = DateTime.utc_now()
      binary_token = <<1, 2, 3, 4, 5>>

      schema = %{
        id: "token-123",
        token: binary_token,
        context: "session",
        sent_to: "user@example.com",
        authenticated_at: now,
        user_id: "user-456",
        inserted_at: now
      }

      user_token = UserToken.from_schema(schema)

      assert %UserToken{} = user_token
      assert user_token.id == "token-123"
      assert user_token.token == binary_token
      assert user_token.context == "session"
      assert user_token.sent_to == "user@example.com"
      assert user_token.authenticated_at == now
      assert user_token.user_id == "user-456"
      assert user_token.inserted_at == now
    end

    test "returns nil when given nil" do
      assert UserToken.from_schema(nil) == nil
    end

    test "handles missing fields by using nil" do
      schema = %{
        id: "token-789",
        context: "login"
      }

      user_token = UserToken.from_schema(schema)

      assert user_token.id == "token-789"
      assert user_token.context == "login"
      assert user_token.token == nil
      assert user_token.sent_to == nil
      assert user_token.authenticated_at == nil
      assert user_token.user_id == nil
      assert user_token.inserted_at == nil
    end

    test "works with struct input" do
      # Using a simple struct to test struct conversion
      schema = %{
        __struct__: SomeTestSchema,
        id: "token-abc",
        token: "raw_token",
        context: "change:old@email.com",
        sent_to: nil,
        authenticated_at: nil,
        user_id: nil,
        inserted_at: nil
      }

      user_token = UserToken.from_schema(schema)

      assert user_token.id == "token-abc"
      assert user_token.token == "raw_token"
      assert user_token.context == "change:old@email.com"
    end
  end

  describe "context types" do
    test "supports session context" do
      schema = %{context: "session", id: "1", user_id: "user-1"}
      user_token = UserToken.from_schema(schema)

      assert user_token.context == "session"
    end

    test "supports login context" do
      schema = %{context: "login", id: "2", user_id: "user-1", sent_to: "user@example.com"}
      user_token = UserToken.from_schema(schema)

      assert user_token.context == "login"
    end

    test "supports change email context" do
      schema = %{context: "change:old@email.com", id: "3", user_id: "user-1"}
      user_token = UserToken.from_schema(schema)

      assert user_token.context == "change:old@email.com"
    end
  end
end
