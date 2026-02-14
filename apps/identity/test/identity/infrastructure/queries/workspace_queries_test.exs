defmodule Identity.Infrastructure.Queries.WorkspaceQueriesTest do
  use Identity.DataCase, async: true

  alias Identity.Infrastructure.Queries.WorkspaceQueries

  import Identity.AccountsFixtures
  import Identity.WorkspacesFixtures

  describe "base/0" do
    test "returns WorkspaceSchema queryable" do
      query = WorkspaceQueries.base()
      assert query == Identity.Infrastructure.Schemas.WorkspaceSchema
    end
  end

  describe "for_user/2" do
    test "filters by user membership" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        WorkspaceQueries.base()
        |> WorkspaceQueries.for_user(user)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == workspace.id
    end

    test "excludes workspaces where user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      _workspace = workspace_fixture(user1)

      result =
        WorkspaceQueries.base()
        |> WorkspaceQueries.for_user(user2)
        |> Repo.all()

      assert result == []
    end
  end

  describe "for_user_by_id/2" do
    test "finds workspace by ID for user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        WorkspaceQueries.for_user_by_id(user, workspace.id)
        |> Repo.one()

      assert result.id == workspace.id
    end

    test "returns nil when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      result =
        WorkspaceQueries.for_user_by_id(user2, workspace.id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "for_user_by_slug/2" do
    test "finds workspace by slug for user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        WorkspaceQueries.for_user_by_slug(user, workspace.slug)
        |> Repo.one()

      assert result.id == workspace.id
    end
  end

  describe "for_user_by_slug_with_member/2" do
    test "preloads member record" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        WorkspaceQueries.for_user_by_slug_with_member(user, workspace.slug)
        |> Repo.one()

      assert result.id == workspace.id
      assert length(result.workspace_members) == 1
      assert hd(result.workspace_members).user_id == user.id
    end
  end

  describe "active/1" do
    test "filters out archived workspaces" do
      user = user_fixture()
      active_workspace = workspace_fixture(user)

      result =
        WorkspaceQueries.base()
        |> WorkspaceQueries.active()
        |> WorkspaceQueries.for_user(user)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == active_workspace.id
    end
  end

  describe "ordered/1" do
    test "orders by inserted_at descending" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "First"})
      workspace2 = workspace_fixture(user, %{name: "Second"})

      # Update inserted_at to ensure ordering
      Repo.update_all(
        from(w in Identity.Infrastructure.Schemas.WorkspaceSchema,
          where: w.id == ^workspace1.id
        ),
        set: [inserted_at: ~U[2025-01-01 10:00:00Z]]
      )

      Repo.update_all(
        from(w in Identity.Infrastructure.Schemas.WorkspaceSchema,
          where: w.id == ^workspace2.id
        ),
        set: [inserted_at: ~U[2025-01-02 10:00:00Z]]
      )

      result =
        WorkspaceQueries.base()
        |> WorkspaceQueries.for_user(user)
        |> WorkspaceQueries.ordered()
        |> Repo.all()

      assert length(result) == 2
      assert hd(result).id == workspace2.id
    end
  end

  describe "exists?/1" do
    test "returns count for existing workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      count =
        WorkspaceQueries.exists?(workspace.id)
        |> Repo.one()

      assert count == 1
    end

    test "returns 0 when workspace doesn't exist" do
      count =
        WorkspaceQueries.exists?(Ecto.UUID.generate())
        |> Repo.one()

      assert count == 0
    end
  end

  describe "find_member_by_email/2" do
    test "finds member case-insensitively" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      member =
        WorkspaceQueries.find_member_by_email(workspace.id, String.upcase(user.email))
        |> Repo.one()

      assert member.email == user.email
    end
  end

  describe "list_members/1" do
    test "returns all members ordered by join/invite time" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      member2 = user_fixture()
      add_workspace_member_fixture(workspace.id, member2, :admin)

      members =
        WorkspaceQueries.list_members(workspace.id)
        |> Repo.all()

      assert length(members) == 2
    end
  end

  describe "get_member/2" do
    test "finds member by user and workspace" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      member =
        WorkspaceQueries.get_member(user, workspace.id)
        |> Repo.one()

      assert member.user_id == user.id
      assert member.workspace_id == workspace.id
    end
  end

  describe "find_pending_invitation/2" do
    test "finds unaccepted invitation" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      _invitation = pending_invitation_fixture(workspace.id, "invited@example.com", :member)

      # Create a user with a matching ID for pending
      invited_user = user_fixture(%{email: "invited@example.com"})

      result =
        WorkspaceQueries.find_pending_invitation(workspace.id, invited_user.id)
        |> Repo.one()

      # Should not find since user_id doesn't match (invitation has nil user_id)
      # but the query uses `wm.user_id == ^user_id or is_nil(wm.user_id)`
      assert result != nil
      assert result.email == "invited@example.com"
    end
  end

  describe "find_pending_invitations_by_email/1" do
    test "finds all pending invitations for email" do
      user = user_fixture()
      workspace = workspace_fixture(user)
      _invitation = pending_invitation_fixture(workspace.id, "pending@example.com", :member)

      results =
        WorkspaceQueries.find_pending_invitations_by_email("pending@example.com")
        |> Repo.all()

      assert length(results) == 1
      assert hd(results).email == "pending@example.com"
    end
  end

  describe "with_workspace_and_inviter/1" do
    test "preloads workspace and inviter associations" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      _invitation =
        pending_invitation_fixture(workspace.id, "invited2@example.com", :member,
          invited_by: user.id
        )

      results =
        WorkspaceQueries.find_pending_invitations_by_email("invited2@example.com")
        |> WorkspaceQueries.with_workspace_and_inviter()
        |> Repo.all()

      assert length(results) == 1
      member = hd(results)
      assert member.workspace.id == workspace.id
      assert member.inviter.id == user.id
    end
  end
end
