defmodule Jarga.Agents.Domain.Entities.WorkspaceAgentJoinTest do
  use ExUnit.Case, async: true

  alias Jarga.Agents.Domain.Entities.WorkspaceAgentJoin

  describe "WorkspaceAgentJoin.new/1" do
    test "creates a new workspace-agent join entity with required fields" do
      attrs = %{
        workspace_id: "ws-123",
        agent_id: "agent-456"
      }

      join = WorkspaceAgentJoin.new(attrs)

      assert %WorkspaceAgentJoin{} = join
      assert join.workspace_id == "ws-123"
      assert join.agent_id == "agent-456"
      assert join.id == nil
    end

    test "creates join with all fields" do
      attrs = %{
        id: "join-789",
        workspace_id: "ws-123",
        agent_id: "agent-456",
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      join = WorkspaceAgentJoin.new(attrs)

      assert join.id == "join-789"
      assert join.inserted_at == ~U[2024-01-01 00:00:00Z]
      assert join.updated_at == ~U[2024-01-01 00:00:00Z]
    end
  end

  describe "WorkspaceAgentJoin.from_schema/1" do
    test "converts schema to domain entity" do
      schema = %{
        __struct__: DummySchema,
        id: "join-123",
        workspace_id: "ws-456",
        agent_id: "agent-789",
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      join = WorkspaceAgentJoin.from_schema(schema)

      assert %WorkspaceAgentJoin{} = join
      assert join.id == "join-123"
      assert join.workspace_id == "ws-456"
      assert join.agent_id == "agent-789"
      assert join.inserted_at == ~U[2024-01-01 00:00:00Z]
      assert join.updated_at == ~U[2024-01-01 00:00:00Z]
    end

    test "preserves all fields from schema" do
      now = DateTime.utc_now()

      schema = %{
        __struct__: DummySchema,
        id: "abc-123",
        workspace_id: "ws-xyz",
        agent_id: "ag-pqr",
        inserted_at: now,
        updated_at: now
      }

      join = WorkspaceAgentJoin.from_schema(schema)

      assert join.id == schema.id
      assert join.workspace_id == schema.workspace_id
      assert join.agent_id == schema.agent_id
      assert join.inserted_at == schema.inserted_at
      assert join.updated_at == schema.updated_at
    end
  end
end
