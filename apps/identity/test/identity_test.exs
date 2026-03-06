defmodule IdentityTest do
  use Identity.DataCase, async: true

  alias Identity.Domain.Entities.ApiKey
  alias Identity.Domain.Policies.ApiKeyPermissionPolicy

  import Identity.AccountsFixtures

  describe "api_key_has_permission?/2" do
    test "delegates permission checks to ApiKeyPermissionPolicy" do
      api_key = ApiKey.new(%{permissions: ["agents:read"]})

      assert Identity.api_key_has_permission?(api_key, "agents:read") ==
               ApiKeyPermissionPolicy.has_permission?(api_key.permissions, "agents:read")
    end

    test "returns true for matching permissions and false for non-matching" do
      api_key = ApiKey.new(%{permissions: ["agents:read"]})

      assert Identity.api_key_has_permission?(api_key, "agents:read")
      refute Identity.api_key_has_permission?(api_key, "agents:write")
    end

    test "returns true for nil permissions for backward compatibility" do
      api_key = ApiKey.new(%{permissions: nil})

      assert Identity.api_key_has_permission?(api_key, "agents:write")
    end
  end

  describe "API key permission flow" do
    test "create_api_key/2 stores permissions end-to-end" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               Identity.create_api_key(user.id, %{
                 name: "Scoped Key",
                 description: "Created through facade",
                 permissions: ["agents:read", "mcp:knowledge.*"]
               })

      assert api_key.permissions == ["agents:read", "mcp:knowledge.*"]
    end

    test "update_api_key/3 updates permissions end-to-end" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               Identity.create_api_key(user.id, %{
                 name: "Editable Key",
                 description: "Before update"
               })

      assert api_key.permissions == nil

      assert {:ok, updated_key} =
               Identity.update_api_key(user.id, api_key.id, %{permissions: ["agents:query"]})

      assert updated_key.permissions == ["agents:query"]
    end
  end
end
