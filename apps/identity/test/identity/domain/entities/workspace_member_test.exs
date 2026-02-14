defmodule Identity.Domain.Entities.WorkspaceMemberTest do
  use ExUnit.Case, async: true

  alias Identity.Domain.Entities.WorkspaceMember

  describe "new/1" do
    test "creates a WorkspaceMember struct with given attributes" do
      attrs = %{
        workspace_id: "ws-123",
        email: "member@example.com",
        role: :member
      }

      member = WorkspaceMember.new(attrs)

      assert member.workspace_id == "ws-123"
      assert member.email == "member@example.com"
      assert member.role == :member
    end

    test "sets all fields from attributes" do
      attrs = %{
        id: "mem-123",
        email: "member@example.com",
        role: :admin,
        invited_at: ~U[2025-01-01 10:00:00Z],
        joined_at: ~U[2025-01-02 10:00:00Z],
        workspace_id: "ws-123",
        user_id: "user-123",
        invited_by: "inviter-123",
        inserted_at: ~U[2025-01-01 10:00:00Z],
        updated_at: ~U[2025-01-01 10:00:00Z]
      }

      member = WorkspaceMember.new(attrs)

      assert member.id == "mem-123"
      assert member.email == "member@example.com"
      assert member.role == :admin
      assert member.invited_at == ~U[2025-01-01 10:00:00Z]
      assert member.joined_at == ~U[2025-01-02 10:00:00Z]
      assert member.workspace_id == "ws-123"
      assert member.user_id == "user-123"
      assert member.invited_by == "inviter-123"
    end
  end

  describe "from_schema/1" do
    test "converts schema to domain entity" do
      schema = %{
        __struct__: SomeSchema,
        id: "test-id",
        workspace_id: "ws-123",
        user_id: "user-123",
        email: "member@example.com",
        role: :member,
        invited_at: ~U[2025-01-01 10:00:00Z],
        joined_at: ~U[2025-01-02 10:00:00Z],
        invited_by: "inviter-123",
        inserted_at: ~U[2025-01-01 10:00:00Z],
        updated_at: ~U[2025-01-01 10:00:00Z]
      }

      entity = WorkspaceMember.from_schema(schema)

      assert %WorkspaceMember{} = entity
      assert entity.id == "test-id"
      assert entity.email == "member@example.com"
      assert entity.role == :member
      assert entity.workspace_id == "ws-123"
      assert entity.user_id == "user-123"
      assert entity.invited_by == "inviter-123"
    end
  end

  describe "accepted?/1" do
    test "returns true when joined_at is not nil" do
      member = %WorkspaceMember{joined_at: ~U[2025-01-01 10:00:00Z]}

      assert WorkspaceMember.accepted?(member) == true
    end

    test "returns false when joined_at is nil" do
      member = %WorkspaceMember{joined_at: nil}

      assert WorkspaceMember.accepted?(member) == false
    end
  end

  describe "pending?/1" do
    test "returns true when joined_at is nil" do
      member = %WorkspaceMember{joined_at: nil}

      assert WorkspaceMember.pending?(member) == true
    end

    test "returns false when joined_at is not nil" do
      member = %WorkspaceMember{joined_at: ~U[2025-01-01 10:00:00Z]}

      assert WorkspaceMember.pending?(member) == false
    end
  end

  describe "owner?/1" do
    test "returns true only for :owner role" do
      assert WorkspaceMember.owner?(%WorkspaceMember{role: :owner}) == true
    end

    test "returns false for :admin role" do
      assert WorkspaceMember.owner?(%WorkspaceMember{role: :admin}) == false
    end

    test "returns false for :member role" do
      assert WorkspaceMember.owner?(%WorkspaceMember{role: :member}) == false
    end

    test "returns false for :guest role" do
      assert WorkspaceMember.owner?(%WorkspaceMember{role: :guest}) == false
    end
  end

  describe "admin_or_owner?/1" do
    test "returns true for :owner role" do
      assert WorkspaceMember.admin_or_owner?(%WorkspaceMember{role: :owner}) == true
    end

    test "returns true for :admin role" do
      assert WorkspaceMember.admin_or_owner?(%WorkspaceMember{role: :admin}) == true
    end

    test "returns false for :member role" do
      assert WorkspaceMember.admin_or_owner?(%WorkspaceMember{role: :member}) == false
    end

    test "returns false for :guest role" do
      assert WorkspaceMember.admin_or_owner?(%WorkspaceMember{role: :guest}) == false
    end
  end
end
