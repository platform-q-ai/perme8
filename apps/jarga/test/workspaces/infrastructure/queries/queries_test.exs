defmodule Jarga.Workspaces.QueriesTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Infrastructure.Queries.Queries

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "active/1" do
    test "filters to only active workspaces" do
      user = user_fixture()
      active_workspace = workspace_fixture(user)

      result =
        Queries.base()
        |> Queries.active()
        |> Queries.for_user(user)
        |> Repo.all()

      assert length(result) == 1
      assert hd(result).id == active_workspace.id
    end
  end

  describe "ordered/1" do
    test "orders workspaces by insertion time" do
      user = user_fixture()
      workspace1 = workspace_fixture(user, %{name: "First"})
      workspace2 = workspace_fixture(user, %{name: "Second"})

      # Update inserted_at to ensure ordering
      import Ecto.Query

      Repo.update_all(
        from(w in Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema,
          where: w.id == ^workspace1.id
        ),
        set: [inserted_at: ~U[2025-01-01 10:00:00Z]]
      )

      Repo.update_all(
        from(w in Jarga.Workspaces.Infrastructure.Schemas.WorkspaceSchema,
          where: w.id == ^workspace2.id
        ),
        set: [inserted_at: ~U[2025-01-02 10:00:00Z]]
      )

      result =
        Queries.base()
        |> Queries.for_user(user)
        |> Queries.ordered()
        |> Repo.all()

      assert length(result) == 2
      # Newest first
      assert hd(result).id == workspace2.id
    end
  end

  describe "for_user_by_id/2" do
    test "finds workspace by ID for user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        Queries.for_user_by_id(user, workspace.id)
        |> Repo.one()

      assert result.id == workspace.id
    end

    test "returns nil when user is not a member" do
      user1 = user_fixture()
      user2 = user_fixture()
      workspace = workspace_fixture(user1)

      result =
        Queries.for_user_by_id(user2, workspace.id)
        |> Repo.one()

      assert result == nil
    end
  end

  describe "for_user_by_slug/2" do
    test "finds workspace by slug for user" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      result =
        Queries.for_user_by_slug(user, workspace.slug)
        |> Repo.one()

      assert result.id == workspace.id
    end
  end

  describe "exists?/1" do
    test "returns query to check if workspace exists" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      count =
        Queries.exists?(workspace.id)
        |> Repo.one()

      assert count == 1
    end

    test "returns 0 when workspace doesn't exist" do
      count =
        Queries.exists?(Ecto.UUID.generate())
        |> Repo.one()

      assert count == 0
    end
  end

  describe "find_member_by_email/2" do
    test "finds member by email case-insensitively" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      member =
        Queries.find_member_by_email(workspace.id, String.upcase(user.email))
        |> Repo.one()

      assert member.email == user.email
    end
  end

  describe "get_member/2" do
    test "gets user's workspace member record" do
      user = user_fixture()
      workspace = workspace_fixture(user)

      member =
        Queries.get_member(user, workspace.id)
        |> Repo.one()

      assert member.user_id == user.id
      assert member.workspace_id == workspace.id
    end
  end
end
