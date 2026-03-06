defmodule Identity.Application.UseCases.CreateApiKeyTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.CreateApiKey

  import Identity.AccountsFixtures

  describe "execute/3" do
    test "stores provided permissions on the created key" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               CreateApiKey.execute(user.id, %{
                 name: "Scoped Key",
                 description: "Key with granular scopes",
                 permissions: ["agents:read", "mcp:knowledge.*"]
               })

      assert api_key.permissions == ["agents:read", "mcp:knowledge.*"]
    end

    test "stores nil permissions when permissions key is omitted" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               CreateApiKey.execute(user.id, %{
                 name: "Legacy Key",
                 description: "No explicit permissions"
               })

      assert api_key.permissions == nil
    end

    test "stores empty list when permissions is empty" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               CreateApiKey.execute(user.id, %{
                 name: "No Access Key",
                 description: "Explicitly deny all",
                 permissions: []
               })

      assert api_key.permissions == []
    end

    test "stores wildcard permissions" do
      user = user_fixture()

      assert {:ok, {api_key, _plain_token}} =
               CreateApiKey.execute(user.id, %{
                 name: "Full Access Key",
                 description: "Wildcard scope",
                 permissions: ["*"]
               })

      assert api_key.permissions == ["*"]
    end
  end
end
