defmodule Agents.Sessions.Domain.Events.QueueSnapshotUpdatedTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Events.QueueSnapshotUpdated

  @valid_attrs %{
    aggregate_id: "queue-user-123",
    actor_id: "user-123",
    user_id: "user-123",
    snapshot: %{}
  }

  describe "event_type/0" do
    test "returns correct type string" do
      assert QueueSnapshotUpdated.event_type() == "sessions.queue_snapshot_updated"
    end
  end

  describe "aggregate_type/0" do
    test "returns correct aggregate type" do
      assert QueueSnapshotUpdated.aggregate_type() == "queue"
    end
  end

  describe "new/1" do
    test "creates event with required fields" do
      event = QueueSnapshotUpdated.new(@valid_attrs)

      assert event.event_id != nil
      assert event.occurred_at != nil
      assert event.event_type == "sessions.queue_snapshot_updated"
      assert event.aggregate_type == "queue"
      assert event.user_id == "user-123"
    end

    test "auto-generates event_id and occurred_at" do
      event = QueueSnapshotUpdated.new(@valid_attrs)

      assert is_binary(event.event_id)
      assert %DateTime{} = event.occurred_at
    end

    test "raises when required fields are missing" do
      assert_raise ArgumentError, fn ->
        QueueSnapshotUpdated.new(%{aggregate_id: "123", actor_id: "123"})
      end
    end
  end
end
