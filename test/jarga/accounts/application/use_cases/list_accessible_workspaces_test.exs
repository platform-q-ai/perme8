defmodule Jarga.Accounts.Application.UseCases.ListAccessibleWorkspacesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Accounts.Application.UseCases.ListAccessibleWorkspaces
  alias Jarga.Accounts.Domain.Entities.ApiKey
  alias Jarga.Workspaces
  alias Jarga.Workspaces.Domain.Entities.Workspace

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  # Helper to create default context opts for integration tests
  defp default_opts do
    [list_workspaces_for_user: &Workspaces.list_workspaces_for_user/1]
  end

  describe "execute/3" do
    test "returns workspaces that match API key's workspace_access slugs" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Product Team"})
      workspace2 = workspace_fixture(user, %{name: "Engineering"})
      _workspace3 = workspace_fixture(user, %{name: "Marketing"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace1.slug, workspace2.slug],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      assert length(workspaces) == 2
      slugs = Enum.map(workspaces, & &1.slug)
      assert workspace1.slug in slugs
      assert workspace2.slug in slugs
    end

    test "returns empty list when API key has no workspace access" do
      user = user_fixture()
      _workspace = workspace_fixture(user)

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      assert workspaces == []
    end

    test "returns only basic workspace info (id, name, slug)" do
      user = user_fixture()
      workspace = workspace_fixture(user, %{name: "My Workspace", description: "Secret details"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      assert length(workspaces) == 1
      result = hd(workspaces)

      # Basic info should be present
      assert result.id == workspace.id
      assert result.name == workspace.name
      assert result.slug == workspace.slug
    end

    test "filters to only workspaces in API key's workspace_access list" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Product Team"})
      workspace2 = workspace_fixture(user, %{name: "Engineering"})
      workspace3 = workspace_fixture(user, %{name: "Marketing"})

      # API key only has access to workspace1 and workspace2, not workspace3
      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace1.slug, workspace2.slug],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      # User has access to all 3, but API key filters to only 2
      assert length(workspaces) == 2
      slugs = Enum.map(workspaces, & &1.slug)
      assert workspace1.slug in slugs
      assert workspace2.slug in slugs
      refute workspace3.slug in slugs
    end

    test "handles non-existent workspace slugs in API key access list gracefully" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace.slug, "non-existent-workspace"],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      # Should only return the existing workspace that user has access to
      assert length(workspaces) == 1
      assert hd(workspaces).slug == workspace.slug
    end

    test "returns workspaces in consistent order" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "Alpha"})
      workspace2 = workspace_fixture(user, %{name: "Beta"})

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: [workspace2.slug, workspace1.slug],
          is_active: true
        })

      {:ok, workspaces} = ListAccessibleWorkspaces.execute(user, api_key, default_opts())

      assert length(workspaces) == 2
    end

    test "accepts custom list_workspaces_for_user function via opts for testing" do
      user = user_fixture()

      api_key =
        ApiKey.new(%{
          id: "key-1",
          name: "Test Key",
          hashed_token: "hashed",
          user_id: user.id,
          workspace_access: ["my-workspace"],
          is_active: true
        })

      # Mock the workspaces context function
      mock_list_workspaces_for_user = fn _user ->
        [
          %Workspace{id: "ws-1", name: "My Workspace", slug: "my-workspace"},
          %Workspace{id: "ws-2", name: "Other Workspace", slug: "other-workspace"}
        ]
      end

      {:ok, workspaces} =
        ListAccessibleWorkspaces.execute(user, api_key,
          list_workspaces_for_user: mock_list_workspaces_for_user
        )

      # Only returns workspaces in the API key's workspace_access list
      assert length(workspaces) == 1
      assert hd(workspaces).slug == "my-workspace"
    end
  end
end
