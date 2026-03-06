defmodule Agents.Sessions.Infrastructure.QueueMirrorTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Entities.{LaneEntry, QueueSnapshot}
  alias Agents.Sessions.Infrastructure.QueueMirror

  describe "compare/2" do
    test "returns :match when legacy state and snapshot agree" do
      legacy = %{running: 1, queued: [%{id: "t1"}], concurrency_limit: 2}

      snapshot =
        QueueSnapshot.new(%{
          user_id: "u1",
          lanes: %{
            processing: [
              LaneEntry.new(%{task_id: "t-run", status: "running", lane: :processing})
            ],
            warm: [LaneEntry.new(%{task_id: "t1", status: "queued", lane: :warm})],
            cold: [],
            awaiting_feedback: [],
            retry_pending: []
          },
          metadata: %{
            concurrency_limit: 2,
            warm_cache_limit: 2,
            running_count: 1,
            available_slots: 1,
            total_queued: 1
          }
        })

      assert :match = QueueMirror.compare(legacy, snapshot)
    end

    test "returns mismatch when running counts differ" do
      legacy = %{running: 2, queued: [], concurrency_limit: 2}

      snapshot =
        QueueSnapshot.new(%{
          user_id: "u1",
          metadata: %{
            running_count: 1,
            concurrency_limit: 2,
            warm_cache_limit: 2,
            available_slots: 1,
            total_queued: 0
          }
        })

      assert {:mismatch, details} = QueueMirror.compare(legacy, snapshot)
      assert Enum.any?(details, fn {k, _} -> k == :running_count end)
    end

    test "returns mismatch when queued counts differ" do
      legacy = %{running: 0, queued: [%{id: "t1"}, %{id: "t2"}], concurrency_limit: 2}

      snapshot =
        QueueSnapshot.new(%{
          user_id: "u1",
          metadata: %{
            running_count: 0,
            concurrency_limit: 2,
            warm_cache_limit: 2,
            available_slots: 2,
            total_queued: 1
          }
        })

      assert {:mismatch, details} = QueueMirror.compare(legacy, snapshot)
      assert Enum.any?(details, fn {k, _} -> k == :queued_count end)
    end
  end
end
