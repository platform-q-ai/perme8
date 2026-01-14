defmodule Jarga.Accounts.Application.UseCases.CreateApiKeyTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Application.UseCases.CreateApiKey
  alias Jarga.Accounts.Domain.Entities.ApiKey

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "execute/3" do
    test "creates API key successfully with valid attributes" do
      user = user_fixture()

      attrs = %{
        name: "Test Key",
        description: "Test description",
        workspace_access: []
      }

      assert {:ok, {%ApiKey{} = api_key, plain_token}} = CreateApiKey.execute(user.id, attrs)

      assert api_key.name == "Test Key"
      assert api_key.description == "Test description"
      assert api_key.workspace_access == []
      assert api_key.is_active == true
      assert api_key.user_id == user.id
      assert api_key.id != nil

      # Plain token should be returned
      assert is_binary(plain_token)
      assert String.length(plain_token) == 64
    end

    test "creates API key without description" do
      user = user_fixture()

      attrs = %{
        name: "Key Without Description",
        workspace_access: []
      }

      assert {:ok, {%ApiKey{} = api_key, _plain_token}} = CreateApiKey.execute(user.id, attrs)

      assert api_key.name == "Key Without Description"
      assert api_key.description == nil
    end

    test "generates unique tokens for each API key" do
      user = user_fixture()

      attrs = %{name: "Key 1", workspace_access: []}

      {:ok, {_key1, token1}} = CreateApiKey.execute(user.id, attrs)
      {:ok, {_key2, token2}} = CreateApiKey.execute(user.id, Map.put(attrs, :name, "Key 2"))

      assert token1 != token2
    end

    test "hashes token in database (not stored plain)" do
      user = user_fixture()

      attrs = %{name: "Hashed Key", workspace_access: []}

      {:ok, {api_key, plain_token}} = CreateApiKey.execute(user.id, attrs)

      # The entity should have the hashed token (from database)
      assert api_key.hashed_token != nil
      assert api_key.hashed_token != plain_token
      # SHA256 hashes are 64 hex characters
      assert String.length(api_key.hashed_token) == 64
      assert Regex.match?(~r/^[a-f0-9]{64}$/, api_key.hashed_token)
    end

    test "creates API key with workspace access when user has access" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      attrs = %{
        name: "Key With Workspace",
        # Use workspace.slug for member_by_slug? validation
        workspace_access: [workspace.slug]
      }

      # Use actual Workspaces module - user is owner, so has access
      assert {:ok, {%ApiKey{} = api_key, _plain_token}} =
               CreateApiKey.execute(user.id, attrs)

      assert api_key.workspace_access == [workspace.slug]
    end

    test "returns error when user doesn't have workspace access" do
      user = user_fixture()
      # Create a workspace that user doesn't own
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      attrs = %{
        name: "Key Without Access",
        # Use workspace.slug for member_by_slug? validation
        workspace_access: [workspace.slug]
      }

      # User doesn't have access to workspace owned by other_user
      assert {:error, :forbidden} = CreateApiKey.execute(user.id, attrs)
    end

    test "sets is_active to true by default" do
      user = user_fixture()

      attrs = %{name: "Active Key", workspace_access: []}

      {:ok, {api_key, _}} = CreateApiKey.execute(user.id, attrs)

      assert api_key.is_active == true
    end

    test "sets user_id correctly" do
      user = user_fixture()

      attrs = %{name: "User Key", workspace_access: []}

      {:ok, {api_key, _}} = CreateApiKey.execute(user.id, attrs)

      assert api_key.user_id == user.id
    end
  end
end
