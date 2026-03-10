defmodule Agents.Sessions.Domain.Policies.QueuePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.QueuePolicy

  describe "should_queue?/2" do
    test "returns true when running count meets concurrency limit" do
      assert QueuePolicy.should_queue?(2, 2)
      assert QueuePolicy.should_queue?(3, 2)
    end

    test "returns false when running count is below concurrency limit" do
      refute QueuePolicy.should_queue?(0, 2)
      refute QueuePolicy.should_queue?(1, 2)
    end
  end

  describe "can_promote?/2" do
    test "returns true when running count is below concurrency limit" do
      assert QueuePolicy.can_promote?(0, 2)
      assert QueuePolicy.can_promote?(1, 2)
    end

    test "returns false when running count meets or exceeds limit" do
      refute QueuePolicy.can_promote?(2, 2)
      refute QueuePolicy.can_promote?(3, 2)
    end
  end

  describe "sort_by_queue_position/1" do
    test "sorts tasks by queue_position ascending" do
      tasks = [
        %{id: "c", queue_position: 3},
        %{id: "a", queue_position: 1},
        %{id: "b", queue_position: 2}
      ]

      sorted = QueuePolicy.sort_by_queue_position(tasks)
      assert Enum.map(sorted, & &1.id) == ["a", "b", "c"]
    end

    test "puts nil queue_position tasks last" do
      tasks = [
        %{id: "b", queue_position: nil},
        %{id: "a", queue_position: 1}
      ]

      sorted = QueuePolicy.sort_by_queue_position(tasks)
      assert Enum.map(sorted, & &1.id) == ["a", "b"]
    end
  end

  describe "next_queue_position/1" do
    test "returns 1 when current max is nil" do
      assert QueuePolicy.next_queue_position(nil) == 1
    end

    test "returns current max plus one" do
      assert QueuePolicy.next_queue_position(3) == 4
    end
  end

  describe "limit validation" do
    test "valid_concurrency_limit?/1 is true only for integers in 0..10" do
      for limit <- 0..10 do
        assert QueuePolicy.valid_concurrency_limit?(limit)
      end

      refute QueuePolicy.valid_concurrency_limit?(-1)
      refute QueuePolicy.valid_concurrency_limit?(11)
      refute QueuePolicy.valid_concurrency_limit?("2")
      refute QueuePolicy.valid_concurrency_limit?(nil)
    end

    test "valid_warm_cache_limit?/1 is true only for integers in 0..5" do
      for limit <- 0..5 do
        assert QueuePolicy.valid_warm_cache_limit?(limit)
      end

      refute QueuePolicy.valid_warm_cache_limit?(-1)
      refute QueuePolicy.valid_warm_cache_limit?(6)
      refute QueuePolicy.valid_warm_cache_limit?("2")
      refute QueuePolicy.valid_warm_cache_limit?(nil)
    end
  end
end
