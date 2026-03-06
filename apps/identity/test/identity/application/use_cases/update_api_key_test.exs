defmodule Identity.Application.UseCases.UpdateApiKeyTest do
  use Identity.DataCase, async: true

  alias Identity.Application.UseCases.UpdateApiKey
  alias Identity.Infrastructure.Repositories.ApiKeyRepository

  import Identity.AccountsFixtures

  describe "execute/4" do
    test "updates permissions when permissions attribute is provided" do
      user = user_fixture()

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Initial Key",
                 description: "Initial",
                 hashed_token: "hashed-token-1",
                 user_id: user.id,
                 workspace_access: [],
                 permissions: nil,
                 is_active: true
               })

      assert {:ok, updated_key} =
               UpdateApiKey.execute(user.id, api_key.id, %{permissions: ["agents:read"]})

      assert updated_key.permissions == ["agents:read"]
    end

    test "does not change permissions when permissions key is omitted" do
      user = user_fixture()

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Scoped Key",
                 description: "Initial",
                 hashed_token: "hashed-token-2",
                 user_id: user.id,
                 workspace_access: [],
                 permissions: ["agents:write"],
                 is_active: true
               })

      assert {:ok, updated_key} =
               UpdateApiKey.execute(user.id, api_key.id, %{name: "Renamed Key"})

      assert updated_key.name == "Renamed Key"
      assert updated_key.permissions == ["agents:write"]
    end

    test "sets empty permissions list when permissions is empty" do
      user = user_fixture()

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Scoped Key",
                 description: "Initial",
                 hashed_token: "hashed-token-3",
                 user_id: user.id,
                 workspace_access: [],
                 permissions: ["agents:write"],
                 is_active: true
               })

      assert {:ok, updated_key} =
               UpdateApiKey.execute(user.id, api_key.id, %{permissions: []})

      assert updated_key.permissions == []
    end
  end
end
