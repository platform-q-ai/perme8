defmodule Jarga.Workspaces.WorkspaceMemberTest do
  use Jarga.DataCase, async: true

  alias Jarga.Workspaces.Domain.Entities.WorkspaceMember
  alias Jarga.Workspaces.Infrastructure.Schemas.WorkspaceMemberSchema

  import Jarga.AccountsFixtures
  import Jarga.WorkspacesFixtures

  describe "domain entity" do
    test "new/1 creates a workspace member entity" do
      attrs = %{
        workspace_id: Ecto.UUID.generate(),
        email: "member@example.com",
        role: :member
      }

      member = WorkspaceMember.new(attrs)

      assert member.email == "member@example.com"
      assert member.role == :member
    end

    test "from_schema/1 converts schema to entity" do
      schema = %WorkspaceMemberSchema{
        id: "test-id",
        workspace_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        email: "member@example.com",
        role: :member,
        invited_at: ~U[2025-01-01 10:00:00Z],
        joined_at: ~U[2025-01-02 10:00:00Z],
        invited_by: Ecto.UUID.generate(),
        inserted_at: ~U[2025-01-01 10:00:00Z],
        updated_at: ~U[2025-01-01 10:00:00Z]
      }

      entity = WorkspaceMember.from_schema(schema)

      assert entity.id == "test-id"
      assert entity.email == "member@example.com"
      assert entity.role == :member
    end

    test "accepted?/1 checks if member has accepted invitation" do
      accepted = %WorkspaceMember{joined_at: ~U[2025-01-01 10:00:00Z]}
      pending = %WorkspaceMember{joined_at: nil}

      assert WorkspaceMember.accepted?(accepted) == true
      assert WorkspaceMember.accepted?(pending) == false
    end

    test "pending?/1 checks if member is pending invitation" do
      accepted = %WorkspaceMember{joined_at: ~U[2025-01-01 10:00:00Z]}
      pending = %WorkspaceMember{joined_at: nil}

      assert WorkspaceMember.pending?(pending) == true
      assert WorkspaceMember.pending?(accepted) == false
    end

    test "owner?/1 checks if member is owner" do
      owner = %WorkspaceMember{role: :owner}
      admin = %WorkspaceMember{role: :admin}
      member = %WorkspaceMember{role: :member}

      assert WorkspaceMember.owner?(owner) == true
      assert WorkspaceMember.owner?(admin) == false
      assert WorkspaceMember.owner?(member) == false
    end

    test "admin_or_owner?/1 checks if member is admin or owner" do
      owner = %WorkspaceMember{role: :owner}
      admin = %WorkspaceMember{role: :admin}
      member = %WorkspaceMember{role: :member}
      guest = %WorkspaceMember{role: :guest}

      assert WorkspaceMember.admin_or_owner?(owner) == true
      assert WorkspaceMember.admin_or_owner?(admin) == true
      assert WorkspaceMember.admin_or_owner?(member) == false
      assert WorkspaceMember.admin_or_owner?(guest) == false
    end
  end

  describe "schema changeset/2" do
    setup do
      user = user_fixture()
      workspace = workspace_fixture(user)
      {:ok, user: user, workspace: workspace}
    end

    test "valid changeset with required fields", %{workspace: workspace} do
      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert changeset.valid?
    end

    test "requires workspace_id" do
      attrs = %{
        email: "member@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).workspace_id
    end

    test "requires email" do
      workspace = workspace_fixture(user_fixture())

      attrs = %{
        workspace_id: workspace.id,
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).email
    end

    test "requires role" do
      workspace = workspace_fixture(user_fixture())

      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com"
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert "can't be blank" in errors_on(changeset).role
    end

    test "role defaults to nil when not provided" do
      member = %WorkspaceMember{}
      assert member.role == nil
    end

    test "accepts valid role values", %{workspace: workspace} do
      valid_roles = [:owner, :admin, :member, :guest]

      for role <- valid_roles do
        attrs = %{
          workspace_id: workspace.id,
          email: "#{role}@example.com",
          role: role
        }

        changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)
        assert changeset.valid?
        assert Ecto.Changeset.get_change(changeset, :role) == role
      end
    end

    test "allows optional user_id", %{user: user, workspace: workspace} do
      attrs = %{
        workspace_id: workspace.id,
        user_id: user.id,
        email: "member@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :user_id) == user.id
    end

    test "allows optional invited_by", %{workspace: workspace} do
      inviter = user_fixture()

      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com",
        role: :member,
        invited_by: inviter.id
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :invited_by) == inviter.id
    end

    test "allows optional invited_at", %{workspace: workspace} do
      invited_at = DateTime.utc_now(:second)

      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com",
        role: :member,
        invited_at: invited_at
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :invited_at) == invited_at
    end

    test "allows optional joined_at", %{workspace: workspace} do
      joined_at = DateTime.utc_now(:second)

      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com",
        role: :member,
        joined_at: joined_at
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert changeset.valid?
      assert Ecto.Changeset.get_change(changeset, :joined_at) == joined_at
    end

    test "validates workspace_id foreign key on insert" do
      fake_workspace_id = Ecto.UUID.generate()

      attrs = %{
        workspace_id: fake_workspace_id,
        email: "member@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).workspace_id
    end

    test "validates user_id foreign key when provided", %{workspace: workspace} do
      fake_user_id = Ecto.UUID.generate()

      attrs = %{
        workspace_id: workspace.id,
        user_id: fake_user_id,
        email: "member@example.com",
        role: :member
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).user_id
    end

    test "validates invited_by foreign key when provided", %{workspace: workspace} do
      fake_inviter_id = Ecto.UUID.generate()

      attrs = %{
        workspace_id: workspace.id,
        email: "member@example.com",
        role: :member,
        invited_by: fake_inviter_id
      }

      changeset = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs)

      assert {:error, changeset} = Repo.insert(changeset)
      assert "does not exist" in errors_on(changeset).invited_by
    end

    test "validates uniqueness of workspace_id and email", %{workspace: workspace} do
      # Create first member
      attrs1 = %{
        workspace_id: workspace.id,
        email: "duplicate@example.com",
        role: :member
      }

      changeset1 = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs1)
      {:ok, _member1} = Repo.insert(changeset1)

      # Try to create second member with same workspace_id and email
      attrs2 = %{
        workspace_id: workspace.id,
        email: "duplicate@example.com",
        role: :admin
      }

      changeset2 = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs2)
      assert {:error, changeset} = Repo.insert(changeset2)
      assert "has already been taken" in errors_on(changeset).workspace_id
    end

    test "allows same email in different workspaces", %{user: user} do
      workspace1 = workspace_fixture(user)
      workspace2 = workspace_fixture(user, %{name: "Workspace 2", slug: "workspace-2"})

      # Create member in workspace1
      attrs1 = %{
        workspace_id: workspace1.id,
        email: "same@example.com",
        role: :member
      }

      changeset1 = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs1)
      {:ok, _member1} = Repo.insert(changeset1)

      # Create member with same email in workspace2
      attrs2 = %{
        workspace_id: workspace2.id,
        email: "same@example.com",
        role: :member
      }

      changeset2 = WorkspaceMemberSchema.changeset(%WorkspaceMemberSchema{}, attrs2)
      assert {:ok, _member2} = Repo.insert(changeset2)
    end
  end
end
