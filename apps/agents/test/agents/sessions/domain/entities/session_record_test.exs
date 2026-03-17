defmodule Agents.Sessions.Domain.Entities.SessionRecordTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.SessionRecord

  @valid_attrs %{
    id: "550e8400-e29b-41d4-a716-446655440000",
    user_id: "660e8400-e29b-41d4-a716-446655440000",
    title: "Fix the build",
    status: "active",
    container_id: "abc123",
    container_port: 8080,
    container_status: "running",
    image: "perme8-opencode",
    sdk_session_id: "sdk-123",
    paused_at: ~U[2026-01-01 12:00:00Z],
    resumed_at: ~U[2026-01-02 12:00:00Z],
    inserted_at: ~U[2026-01-01 10:00:00Z],
    updated_at: ~U[2026-01-01 11:00:00Z]
  }

  describe "new/1" do
    test "creates a SessionRecord from a map of attributes" do
      record = SessionRecord.new(@valid_attrs)

      assert %SessionRecord{} = record
      assert record.id == "550e8400-e29b-41d4-a716-446655440000"
      assert record.user_id == "660e8400-e29b-41d4-a716-446655440000"
      assert record.title == "Fix the build"
      assert record.status == "active"
      assert record.container_id == "abc123"
      assert record.container_port == 8080
      assert record.container_status == "running"
      assert record.image == "perme8-opencode"
      assert record.sdk_session_id == "sdk-123"
      assert record.paused_at == ~U[2026-01-01 12:00:00Z]
      assert record.resumed_at == ~U[2026-01-02 12:00:00Z]
      assert record.inserted_at == ~U[2026-01-01 10:00:00Z]
      assert record.updated_at == ~U[2026-01-01 11:00:00Z]
    end

    test "creates a SessionRecord with defaults for missing fields" do
      record = SessionRecord.new(%{})

      assert %SessionRecord{} = record
      assert is_nil(record.id)
      assert is_nil(record.user_id)
      assert is_nil(record.title)
      assert is_nil(record.status)
      assert is_nil(record.container_id)
      assert is_nil(record.container_port)
      assert is_nil(record.container_status)
      assert is_nil(record.image)
      assert is_nil(record.sdk_session_id)
      assert is_nil(record.paused_at)
      assert is_nil(record.resumed_at)
      assert is_nil(record.inserted_at)
      assert is_nil(record.updated_at)
      assert is_nil(record.task_count)
    end
  end

  describe "struct" do
    test "has all persistence fields" do
      fields = SessionRecord.__struct__() |> Map.keys() |> MapSet.new()

      expected =
        MapSet.new([
          :__struct__,
          :id,
          :user_id,
          :title,
          :status,
          :container_id,
          :container_port,
          :container_status,
          :image,
          :sdk_session_id,
          :paused_at,
          :resumed_at,
          :inserted_at,
          :updated_at,
          :task_count
        ])

      assert MapSet.equal?(fields, expected)
    end
  end
end
