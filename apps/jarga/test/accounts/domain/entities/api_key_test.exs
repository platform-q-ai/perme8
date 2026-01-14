defmodule Jarga.Accounts.Domain.Entities.ApiKeyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Entities.ApiKey

  describe "new/1" do
    test "creates new ApiKey from attributes" do
      attrs = %{
        id: "123",
        name: "Test Key",
        description: "A test API key",
        hashed_token: "hashed_value",
        user_id: "user_123",
        workspace_access: ["workspace1", "workspace2"],
        is_active: true
      }

      api_key = ApiKey.new(attrs)

      assert api_key.id == "123"
      assert api_key.name == "Test Key"
      assert api_key.description == "A test API key"
      assert api_key.hashed_token == "hashed_value"
      assert api_key.user_id == "user_123"
      assert api_key.workspace_access == ["workspace1", "workspace2"]
      assert api_key.is_active == true
    end
  end

  describe "from_schema/1" do
    test "converts from infrastructure schema" do
      schema = %{
        __struct__: SomeSchema,
        id: "123",
        name: "Test Key",
        description: "A test API key",
        hashed_token: "hashed_value",
        user_id: "user_123",
        workspace_access: ["workspace1", "workspace2"],
        is_active: true,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      api_key = ApiKey.from_schema(schema)

      assert api_key.id == "123"
      assert api_key.name == "Test Key"
      assert api_key.description == "A test API key"
      assert api_key.hashed_token == "hashed_value"
      assert api_key.user_id == "user_123"
      assert api_key.workspace_access == ["workspace1", "workspace2"]
      assert api_key.is_active == true
      assert %DateTime{} = api_key.inserted_at
      assert %DateTime{} = api_key.updated_at
    end

    test "returns correct workspace access list" do
      schema = %{
        __struct__: SomeSchema,
        id: "123",
        name: "Test Key",
        description: "A test API key",
        hashed_token: "hashed_value",
        user_id: "user_123",
        workspace_access: ["workspace1", "workspace2", "workspace3"],
        is_active: true,
        inserted_at: DateTime.utc_now(),
        updated_at: DateTime.utc_now()
      }

      api_key = ApiKey.from_schema(schema)

      assert api_key.workspace_access == ["workspace1", "workspace2", "workspace3"]
    end
  end
end

defmodule SomeSchema do
  defstruct [
    :id,
    :name,
    :description,
    :hashed_token,
    :user_id,
    :workspace_access,
    :is_active,
    :inserted_at,
    :updated_at
  ]
end
