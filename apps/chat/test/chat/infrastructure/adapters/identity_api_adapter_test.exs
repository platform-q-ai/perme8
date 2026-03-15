defmodule Chat.Infrastructure.Adapters.IdentityApiAdapterTest do
  use Chat.DataCase, async: true

  alias Chat.Infrastructure.Adapters.IdentityApiAdapter

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "user_exists?/1" do
    test "returns true for an existing user" do
      user = user_fixture()
      assert IdentityApiAdapter.user_exists?(user.id) == true
    end

    test "returns false for a non-existent UUID" do
      assert IdentityApiAdapter.user_exists?(Ecto.UUID.generate()) == false
    end
  end

  describe "validate_workspace_access/2" do
    test "returns :ok for a user who is a member of the workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      assert IdentityApiAdapter.validate_workspace_access(user.id, workspace.id) == :ok
    end

    test "returns {:error, :not_a_member} for a user who is not a member" do
      user = user_fixture()
      other_user = user_fixture()
      workspace = workspace_fixture(other_user)

      assert IdentityApiAdapter.validate_workspace_access(user.id, workspace.id) ==
               {:error, :not_a_member}
    end

    test "returns {:error, :not_a_member} for a non-existent workspace" do
      user = user_fixture()

      assert IdentityApiAdapter.validate_workspace_access(user.id, Ecto.UUID.generate()) ==
               {:error, :not_a_member}
    end
  end
end
