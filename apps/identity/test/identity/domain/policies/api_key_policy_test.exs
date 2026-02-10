defmodule Identity.Domain.Policies.ApiKeyPolicyTest do
  @moduledoc """
  Unit tests for the ApiKeyPolicy domain policy.

  These are pure tests with no database access, testing business rules
  for API key ownership and management authorization.
  """

  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.ApiKey
  alias Identity.Domain.Policies.ApiKeyPolicy

  describe "can_own_api_key?/2" do
    test "returns true when user_id matches api_key's user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, "user-123") == true
    end

    test "returns false when user_id does not match api_key's user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, "user-456") == false
    end

    test "returns false when api_key user_id is nil" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: nil
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, "user-123") == false
    end

    test "returns false when comparing with nil user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_own_api_key?(api_key, nil) == false
    end

    test "returns true when both user_ids are nil" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: nil
        })

      # nil == nil returns true
      assert ApiKeyPolicy.can_own_api_key?(api_key, nil) == true
    end

    test "works with plain maps" do
      api_key_map = %{user_id: "user-abc"}

      assert ApiKeyPolicy.can_own_api_key?(api_key_map, "user-abc") == true
      assert ApiKeyPolicy.can_own_api_key?(api_key_map, "user-xyz") == false
    end
  end

  describe "can_manage_api_key?/2" do
    test "returns true when user_id matches api_key's user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, "user-123") == true
    end

    test "returns false when user_id does not match api_key's user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, "user-456") == false
    end

    test "returns false when api_key user_id is nil" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: nil
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, "user-123") == false
    end

    test "returns false when comparing with nil user_id" do
      api_key =
        ApiKey.new(%{
          name: "Test Key",
          user_id: "user-123"
        })

      assert ApiKeyPolicy.can_manage_api_key?(api_key, nil) == false
    end

    test "works with plain maps" do
      api_key_map = %{user_id: "manager-123"}

      assert ApiKeyPolicy.can_manage_api_key?(api_key_map, "manager-123") == true
      assert ApiKeyPolicy.can_manage_api_key?(api_key_map, "other-user") == false
    end
  end

  describe "ownership and management relationship" do
    test "owner can always manage their own key" do
      api_key =
        ApiKey.new(%{
          name: "My Key",
          user_id: "owner-id"
        })

      # If you own a key, you can manage it
      assert ApiKeyPolicy.can_own_api_key?(api_key, "owner-id") == true
      assert ApiKeyPolicy.can_manage_api_key?(api_key, "owner-id") == true
    end

    test "non-owner cannot manage key" do
      api_key =
        ApiKey.new(%{
          name: "Someone Else's Key",
          user_id: "owner-id"
        })

      # If you don't own a key, you can't manage it
      assert ApiKeyPolicy.can_own_api_key?(api_key, "other-user") == false
      assert ApiKeyPolicy.can_manage_api_key?(api_key, "other-user") == false
    end
  end
end
