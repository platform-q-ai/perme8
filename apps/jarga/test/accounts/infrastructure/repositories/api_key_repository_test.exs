defmodule Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepositoryTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Infrastructure.Repositories.ApiKeyRepository

  import Jarga.AccountsFixtures

  describe "insert/2" do
    test "insert creates new API key" do
      user = user_fixture()

      attrs = %{
        name: "Test Key",
        hashed_token: "hashed_token_123",
        user_id: user.id,
        workspace_access: ["workspace-1"],
        is_active: true
      }

      assert {:ok, schema} = ApiKeyRepository.insert(Jarga.Repo, attrs)
      assert schema.id
      assert schema.name == "Test Key"
    end
  end

  describe "update/2" do
    test "update modifies existing API key" do
      user = user_fixture()

      {:ok, api_key} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Original Name",
          hashed_token: "hashed_token_123",
          user_id: user.id
        })

      assert {:ok, updated} =
               ApiKeyRepository.update(Jarga.Repo, api_key, %{name: "Updated Name"})

      assert updated.name == "Updated Name"
      assert updated.id == api_key.id
    end
  end

  describe "get_by_id/2" do
    test "get_by_id returns API key" do
      user = user_fixture()

      {:ok, api_key} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Test Key",
          hashed_token: "hashed_token_123",
          user_id: user.id
        })

      assert {:ok, found} = ApiKeyRepository.get_by_id(Jarga.Repo, api_key.id)
      assert found.id == api_key.id
      assert is_struct(found, Jarga.Accounts.Domain.Entities.ApiKey)
    end

    test "get_by_id returns :not_found for non-existent id" do
      result = ApiKeyRepository.get_by_id(Jarga.Repo, Ecto.UUID.generate())

      assert result == {:error, :not_found}
    end
  end

  describe "get_by_hashed_token/2" do
    test "get_by_hashed_token returns API key" do
      user = user_fixture()

      {:ok, _api_key} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Test Key",
          hashed_token: "hashed_token_123",
          user_id: user.id
        })

      assert {:ok, found} = ApiKeyRepository.get_by_hashed_token(Jarga.Repo, "hashed_token_123")
      assert found.hashed_token == "hashed_token_123"
    end

    test "get_by_hashed_token returns :not_found for non-existent token" do
      result = ApiKeyRepository.get_by_hashed_token(Jarga.Repo, "non_existent_token")

      assert result == {:error, :not_found}
    end
  end

  describe "list_by_user_id/2" do
    test "list_by_user_id returns all user's API keys" do
      user = user_fixture()

      {:ok, _} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Key 1",
          hashed_token: "hashed_token_1",
          user_id: user.id
        })

      {:ok, _} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Key 2",
          hashed_token: "hashed_token_2",
          user_id: user.id
        })

      {:ok, keys} = ApiKeyRepository.list_by_user_id(Jarga.Repo, user.id)

      assert length(keys) == 2
      assert Enum.all?(keys, &is_struct(&1, Jarga.Accounts.Domain.Entities.ApiKey))
    end

    test "list_by_user_id returns empty list for user with no keys" do
      user = user_fixture()

      {:ok, keys} = ApiKeyRepository.list_by_user_id(Jarga.Repo, user.id)

      assert keys == []
    end
  end

  describe "exists_by_id_and_hashed_token/3" do
    test "exists returns true for existing API key" do
      user = user_fixture()

      {:ok, api_key} =
        ApiKeyRepository.insert(Jarga.Repo, %{
          name: "Test Key",
          hashed_token: "hashed_token_123",
          user_id: user.id
        })

      assert ApiKeyRepository.exists_by_id_and_hashed_token?(
               Jarga.Repo,
               api_key.id,
               api_key.hashed_token
             )
    end

    test "exists returns false for non-existent API key" do
      refute ApiKeyRepository.exists_by_id_and_hashed_token?(
               Jarga.Repo,
               Ecto.UUID.generate(),
               "non_existent_token"
             )
    end
  end
end
