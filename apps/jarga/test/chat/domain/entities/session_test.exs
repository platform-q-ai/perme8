defmodule Jarga.Chat.Domain.Entities.SessionTest do
  use ExUnit.Case, async: true

  alias Jarga.Chat.Domain.Entities.Session

  describe "Session.new/1" do
    test "creates a new session entity with required fields" do
      attrs = %{
        user_id: "user-123",
        title: "My Chat Session"
      }

      session = Session.new(attrs)

      assert %Session{} = session
      assert session.user_id == "user-123"
      assert session.title == "My Chat Session"
      assert session.messages == []
    end

    test "creates a new session with optional fields" do
      attrs = %{
        user_id: "user-123",
        title: "Project Chat",
        workspace_id: "ws-456",
        project_id: "proj-789"
      }

      session = Session.new(attrs)

      assert session.workspace_id == "ws-456"
      assert session.project_id == "proj-789"
    end

    test "creates session with default empty messages list" do
      session = Session.new(%{user_id: "user-123"})

      assert session.messages == []
    end
  end

  describe "Session.from_schema/1" do
    test "converts schema to domain entity" do
      schema = %{
        __struct__: DummySchema,
        id: "session-123",
        user_id: "user-456",
        title: "Test Session",
        workspace_id: "ws-789",
        project_id: nil,
        messages: [],
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      session = Session.from_schema(schema)

      assert %Session{} = session
      assert session.id == "session-123"
      assert session.user_id == "user-456"
      assert session.title == "Test Session"
      assert session.workspace_id == "ws-789"
      assert session.project_id == nil
      assert session.messages == []
    end

    test "handles unloaded messages association" do
      schema = %{
        __struct__: DummySchema,
        id: "session-123",
        user_id: "user-456",
        title: "Test",
        workspace_id: nil,
        project_id: nil,
        messages: %Ecto.Association.NotLoaded{},
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      session = Session.from_schema(schema)

      assert session.messages == []
    end

    test "handles nil messages" do
      schema = %{
        __struct__: DummySchema,
        id: "session-123",
        user_id: "user-456",
        title: "Test",
        workspace_id: nil,
        project_id: nil,
        messages: nil,
        inserted_at: ~U[2024-01-01 00:00:00Z],
        updated_at: ~U[2024-01-01 00:00:00Z]
      }

      session = Session.from_schema(schema)

      assert session.messages == []
    end
  end
end
