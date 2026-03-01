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

  describe "can_delete?/1" do
    test "returns true for terminal statuses" do
      assert TaskPolicy.can_delete?("completed")
      assert TaskPolicy.can_delete?("failed")
      assert TaskPolicy.can_delete?("cancelled")
    end

    test "returns false for active statuses" do
      refute TaskPolicy.can_delete?("pending")
      refute TaskPolicy.can_delete?("starting")
      refute TaskPolicy.can_delete?("running")
    end
  end
end
