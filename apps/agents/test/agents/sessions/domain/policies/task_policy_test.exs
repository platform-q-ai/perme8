defmodule Agents.Sessions.Domain.Policies.TaskPolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.TaskPolicy

  describe "valid_status?/1" do
    test "returns true for all valid statuses" do
      for status <- ["pending", "starting", "running", "completed", "failed", "cancelled"] do
        assert TaskPolicy.valid_status?(status), "expected #{status} to be valid"
      end
    end

    test "returns false for invalid statuses" do
      refute TaskPolicy.valid_status?("unknown")
      refute TaskPolicy.valid_status?("paused")
      refute TaskPolicy.valid_status?("")
      refute TaskPolicy.valid_status?(nil)
    end
  end

  describe "can_cancel?/1" do
    test "returns true for cancellable statuses" do
      assert TaskPolicy.can_cancel?("pending")
      assert TaskPolicy.can_cancel?("starting")
      assert TaskPolicy.can_cancel?("running")
    end

    test "returns false for non-cancellable statuses" do
      refute TaskPolicy.can_cancel?("completed")
      refute TaskPolicy.can_cancel?("failed")
      refute TaskPolicy.can_cancel?("cancelled")
    end
  end

  describe "valid_status_transition?/2" do
    test "pending can transition to starting" do
      assert TaskPolicy.valid_status_transition?("pending", "starting")
    end

    test "pending can transition to cancelled" do
      assert TaskPolicy.valid_status_transition?("pending", "cancelled")
    end

    test "starting can transition to running" do
      assert TaskPolicy.valid_status_transition?("starting", "running")
    end

    test "starting can transition to failed" do
      assert TaskPolicy.valid_status_transition?("starting", "failed")
    end

    test "starting can transition to cancelled" do
      assert TaskPolicy.valid_status_transition?("starting", "cancelled")
    end

    test "running can transition to completed" do
      assert TaskPolicy.valid_status_transition?("running", "completed")
    end

    test "running can transition to failed" do
      assert TaskPolicy.valid_status_transition?("running", "failed")
    end

    test "running can transition to cancelled" do
      assert TaskPolicy.valid_status_transition?("running", "cancelled")
    end

    test "completed cannot transition to any status" do
      refute TaskPolicy.valid_status_transition?("completed", "running")
      refute TaskPolicy.valid_status_transition?("completed", "pending")
      refute TaskPolicy.valid_status_transition?("completed", "failed")
    end

    test "failed cannot transition to any status" do
      refute TaskPolicy.valid_status_transition?("failed", "running")
      refute TaskPolicy.valid_status_transition?("failed", "pending")
      refute TaskPolicy.valid_status_transition?("failed", "completed")
    end

    test "cancelled cannot transition to any status" do
      refute TaskPolicy.valid_status_transition?("cancelled", "running")
      refute TaskPolicy.valid_status_transition?("cancelled", "pending")
    end

    test "pending cannot transition to completed directly" do
      refute TaskPolicy.valid_status_transition?("pending", "completed")
    end

    test "pending cannot transition to running directly" do
      refute TaskPolicy.valid_status_transition?("pending", "running")
    end
  end
end
