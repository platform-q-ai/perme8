defmodule Agents.Sessions.Domain.Policies.SessionStateMachinePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.SessionStateMachinePolicy

  describe "can_transition?/2" do
    test "active -> paused is valid" do
      assert SessionStateMachinePolicy.can_transition?(:active, :paused)
    end

    test "paused -> active is valid" do
      assert SessionStateMachinePolicy.can_transition?(:paused, :active)
    end

    test "active -> completed is valid" do
      assert SessionStateMachinePolicy.can_transition?(:active, :completed)
    end

    test "active -> failed is valid" do
      assert SessionStateMachinePolicy.can_transition?(:active, :failed)
    end

    test "paused -> failed is valid" do
      assert SessionStateMachinePolicy.can_transition?(:paused, :failed)
    end

    test "terminalization transitions are valid" do
      assert SessionStateMachinePolicy.can_transition?(:active, :terminated)
      assert SessionStateMachinePolicy.can_transition?(:paused, :terminated)
      assert SessionStateMachinePolicy.can_transition?(:completed, :terminated)
      assert SessionStateMachinePolicy.can_transition?(:failed, :terminated)
    end

    test "completed -> paused is invalid" do
      refute SessionStateMachinePolicy.can_transition?(:completed, :paused)
    end

    test "failed -> active is invalid" do
      refute SessionStateMachinePolicy.can_transition?(:failed, :active)
    end

    test "paused -> completed is invalid" do
      refute SessionStateMachinePolicy.can_transition?(:paused, :completed)
    end

    test "works with string arguments" do
      assert SessionStateMachinePolicy.can_transition?("active", "paused")
      refute SessionStateMachinePolicy.can_transition?("completed", "paused")
    end
  end

  describe "transition/2" do
    test "returns {:ok, new_status} for valid transitions" do
      assert {:ok, :paused} = SessionStateMachinePolicy.transition(:active, :paused)
      assert {:ok, :active} = SessionStateMachinePolicy.transition(:paused, :active)
    end

    test "returns {:error, :invalid_transition} for invalid transitions" do
      assert {:error, :invalid_transition} =
               SessionStateMachinePolicy.transition(:completed, :paused)
    end
  end

  describe "predicate functions" do
    test "can_pause? is true only for active" do
      assert SessionStateMachinePolicy.can_pause?(:active)
      assert SessionStateMachinePolicy.can_pause?("active")
      refute SessionStateMachinePolicy.can_pause?(:paused)
      refute SessionStateMachinePolicy.can_pause?(:completed)
    end

    test "can_resume? is true only for paused" do
      assert SessionStateMachinePolicy.can_resume?(:paused)
      assert SessionStateMachinePolicy.can_resume?("paused")
      refute SessionStateMachinePolicy.can_resume?(:active)
      refute SessionStateMachinePolicy.can_resume?(:completed)
    end

    test "can_complete? is true only for active" do
      assert SessionStateMachinePolicy.can_complete?(:active)
      refute SessionStateMachinePolicy.can_complete?(:paused)
    end

    test "can_fail? is true for active and paused" do
      assert SessionStateMachinePolicy.can_fail?(:active)
      assert SessionStateMachinePolicy.can_fail?(:paused)
      refute SessionStateMachinePolicy.can_fail?(:completed)
      refute SessionStateMachinePolicy.can_fail?(:failed)
    end

    test "can_terminate? is true for active, paused, completed, and failed" do
      assert SessionStateMachinePolicy.can_terminate?(:active)
      assert SessionStateMachinePolicy.can_terminate?(:paused)
      assert SessionStateMachinePolicy.can_terminate?(:completed)
      assert SessionStateMachinePolicy.can_terminate?(:failed)
      refute SessionStateMachinePolicy.can_terminate?(:terminated)
    end
  end
end
