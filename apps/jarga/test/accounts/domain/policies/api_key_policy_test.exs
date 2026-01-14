defmodule Jarga.Accounts.Domain.Policies.ApiKeyPolicyTest do
  use ExUnit.Case, async: true

  alias Jarga.Accounts.Domain.Entities.ApiKey
  alias Jarga.Accounts.Domain.Policies.ApiKeyPolicy

  describe "can_own_api_key?/2" do
    test "returns true when user_id matches" do
      api_key =
        ApiKey.new(%{
          id: "123",
          name: "Test Key",
          description: "Test",
          hashed_token: "hashed",
          user_id: "user_123",
          workspace_access: [],
          is_active: true
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, "user_123") == true
    end

    test "returns false when user_id differs" do
      api_key =
        ApiKey.new(%{
          id: "123",
          name: "Test Key",
          description: "Test",
          hashed_token: "hashed",
          user_id: "user_123",
          workspace_access: [],
          is_active: true
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, "user_456") == false
    end
  end

  describe "can_manage_api_key?/2" do
    test "returns true for owner" do
      api_key =
        ApiKey.new(%{
          id: "123",
          name: "Test Key",
          description: "Test",
          hashed_token: "hashed",
          user_id: "user_123",
          workspace_access: [],
          is_active: true
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, "user_123") == true
    end

    test "returns false for non-owner" do
      api_key =
        ApiKey.new(%{
          id: "123",
          name: "Test Key",
          description: "Test",
          hashed_token: "hashed",
          user_id: "user_123",
          workspace_access: [],
          is_active: true
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, "user_456") == false
    end
  end
end
