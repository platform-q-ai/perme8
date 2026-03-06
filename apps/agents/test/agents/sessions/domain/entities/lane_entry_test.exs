defmodule Agents.Sessions.Domain.Entities.LaneEntryTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.LaneEntry

  describe "new/1" do
    test "creates lane entry with provided attributes" do
      now = DateTime.utc_now()

      entry =
        LaneEntry.new(%{
          task_id: "task-123",
          instruction: "Implement queue refactor",
          status: "queued",
          lane: :cold,
          container_id: nil,
          warm_state: :cold,
          queue_position: 2,
          error: nil,
          queued_at: now,
          started_at: nil
        })

      assert %LaneEntry{} = entry
      assert entry.task_id == "task-123"
      assert entry.retry_count == 0
      assert entry.warm_state == :cold
    end

    test "allows overriding retry_count" do
      entry = LaneEntry.new(%{task_id: "task-123", retry_count: 2})

      assert entry.retry_count == 2
    end
  end

  describe "warm?/1" do
    test "returns true for warm and hot states" do
      assert LaneEntry.warm?(LaneEntry.new(%{warm_state: :warm}))
      assert LaneEntry.warm?(LaneEntry.new(%{warm_state: :hot}))
    end

    test "returns false for cold and warming states" do
      refute LaneEntry.warm?(LaneEntry.new(%{warm_state: :cold}))
      refute LaneEntry.warm?(LaneEntry.new(%{warm_state: :warming}))
    end
  end

  describe "cold?/1" do
    test "returns true only for cold state" do
      assert LaneEntry.cold?(LaneEntry.new(%{warm_state: :cold}))
      refute LaneEntry.cold?(LaneEntry.new(%{warm_state: :warm}))
      refute LaneEntry.cold?(LaneEntry.new(%{warm_state: :hot}))
      refute LaneEntry.cold?(LaneEntry.new(%{warm_state: :warming}))
    end
  end
end
