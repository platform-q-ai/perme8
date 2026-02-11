defmodule Identity.Domain.Entities.ApiKeyTest do
  @moduledoc """
  Unit tests for the ApiKey domain entity.

  These are pure tests with no database access, testing the entity's
  value object behavior and business logic.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.ApiKey

  describe "new/1" do
    test "creates an ApiKey struct with provided attributes" do
      now = DateTime.utc_now()

      attrs = %{
        id: "key-123",
        name: "Production Key",
        description: "For production use",
        hashed_token: "hashed_value",
        user_id: "user-456",
        workspace_access: ["workspace-1", "workspace-2"],
        is_active: true,
        inserted_at: now,
        updated_at: now
      }

      api_key = ApiKey.new(attrs)

      assert %ApiKey{} = api_key
      assert api_key.id == "key-123"
      assert api_key.name == "Production Key"
      assert api_key.description == "For production use"
      assert api_key.hashed_token == "hashed_value"
      assert api_key.user_id == "user-456"
      assert api_key.workspace_access == ["workspace-1", "workspace-2"]
      assert api_key.is_active == true
      assert api_key.inserted_at == now
      assert api_key.updated_at == now
    end

    test "allows creating with minimal attributes" do
      api_key = ApiKey.new(%{name: "Test Key", user_id: "user-1"})

      assert api_key.name == "Test Key"
      assert api_key.user_id == "user-1"
      assert api_key.workspace_access == nil
      assert api_key.is_active == nil
    end
  end

  describe "from_schema/1" do
    test "converts a schema-like struct to ApiKey entity" do
      now = DateTime.utc_now()

      schema = %{
        __struct__: SomeSchema,
        id: "key-789",
        name: "My API Key",
        description: "Description here",
        hashed_token: "secret_hash",
        user_id: "user-abc",
        workspace_access: ["ws-1"],
        is_active: true,
        inserted_at: now,
        updated_at: now
      }

      api_key = ApiKey.from_schema(schema)

      assert %ApiKey{} = api_key
      assert api_key.id == "key-789"
      assert api_key.name == "My API Key"
      assert api_key.description == "Description here"
      assert api_key.hashed_token == "secret_hash"
      assert api_key.user_id == "user-abc"
      assert api_key.workspace_access == ["ws-1"]
      assert api_key.is_active == true
      assert api_key.inserted_at == now
      assert api_key.updated_at == now
    end

    test "defaults workspace_access to empty list when nil in schema" do
      schema = %{
        __struct__: SomeSchema,
        id: "key-def",
        name: "No Workspaces",
        description: nil,
        hashed_token: "hash",
        user_id: "user-1",
        workspace_access: nil,
        is_active: false,
        inserted_at: nil,
        updated_at: nil
      }

      api_key = ApiKey.from_schema(schema)

      assert api_key.workspace_access == []
    end

    test "preserves workspace_access when present" do
      schema = %{
        __struct__: SomeSchema,
        id: "key-ghi",
        name: "With Workspaces",
        description: nil,
        hashed_token: "hash",
        user_id: "user-1",
        workspace_access: ["workspace-a", "workspace-b"],
        is_active: true,
        inserted_at: nil,
        updated_at: nil
      }

      api_key = ApiKey.from_schema(schema)

      assert api_key.workspace_access == ["workspace-a", "workspace-b"]
    end
  end

  describe "Inspect protocol" do
    test "redacts hashed_token field" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          hashed_token: "super_secret_hash_value"
        })

      inspected = inspect(api_key)

      assert inspected =~ "**redacted**"
      refute inspected =~ "super_secret_hash_value"
    end

    test "shows nil for nil hashed_token" do
      api_key = ApiKey.new(%{name: "Test Key"})

      inspected = inspect(api_key)

      assert inspected =~ "Identity.Domain.Entities.ApiKey"
      # When nil, it should show nil not redacted
      refute inspected =~ "**redacted**"
    end

    test "includes non-sensitive fields" do
      api_key =
        ApiKey.new(%{
          name: "My Key",
          description: "Test description",
          user_id: "user-123"
        })

      inspected = inspect(api_key)

      assert inspected =~ "My Key"
      assert inspected =~ "Test description"
      assert inspected =~ "user-123"
    end
  end
end
