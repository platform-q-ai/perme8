defmodule Identity.Infrastructure.Repositories.ApiKeyRepositoryTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Repositories.ApiKeyRepository

  import Identity.AccountsFixtures

  describe "insert/2" do
    test "stores and returns permissions when provided" do
      user = user_fixture()
      permissions = ["agents:read", "mcp:knowledge.search"]

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Scoped Key",
                 hashed_token: unique_hashed_token(),
                 user_id: user.id,
                 workspace_access: [],
                 permissions: permissions
               })

      assert api_key.permissions == permissions
    end

    test "stores nil permissions when omitted" do
      user = user_fixture()

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Legacy Key",
                 hashed_token: unique_hashed_token(),
                 user_id: user.id,
                 workspace_access: []
               })

      assert api_key.permissions == nil
    end
  end

  describe "update/3" do
    test "updates permissions when provided" do
      user = user_fixture()

      assert {:ok, api_key} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Key",
                 hashed_token: unique_hashed_token(),
                 user_id: user.id,
                 workspace_access: [],
                 permissions: ["agents:read"]
               })

      assert {:ok, updated} =
               ApiKeyRepository.update(Repo, api_key.id, %{permissions: ["agents:write"]})

      assert updated.permissions == ["agents:write"]
    end
  end

  describe "get_by_id/2" do
    test "returns entity with permissions" do
      user = user_fixture()

      assert {:ok, created} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Lookup Key",
                 hashed_token: unique_hashed_token(),
                 user_id: user.id,
                 workspace_access: [],
                 permissions: ["mcp:knowledge.*"]
               })

      assert {:ok, found} = ApiKeyRepository.get_by_id(Repo, created.id)
      assert found.permissions == ["mcp:knowledge.*"]
    end
  end

  describe "get_by_hashed_token/2" do
    test "returns entity with permissions" do
      user = user_fixture()
      hashed_token = unique_hashed_token()

      assert {:ok, _created} =
               ApiKeyRepository.insert(Repo, %{
                 name: "Token Lookup Key",
                 hashed_token: hashed_token,
                 user_id: user.id,
                 workspace_access: [],
                 permissions: ["agents:*"]
               })

      assert {:ok, found} = ApiKeyRepository.get_by_hashed_token(Repo, hashed_token)
      assert found.permissions == ["agents:*"]
    end
  end

  defp unique_hashed_token do
    "hashed-token-#{System.unique_integer([:positive])}"
  end
end
