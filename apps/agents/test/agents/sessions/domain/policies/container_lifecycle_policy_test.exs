defmodule Agents.Sessions.Domain.Policies.ContainerLifecyclePolicyTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Domain.Policies.ContainerLifecyclePolicy

  describe "valid_status?/1" do
    test "accepts all valid statuses" do
      for status <- [:pending, :starting, :running, :stopped, :removed] do
        assert ContainerLifecyclePolicy.valid_status?(status)
      end
    end

    test "rejects invalid statuses" do
      refute ContainerLifecyclePolicy.valid_status?(:invalid)
    end
  end

  describe "can_transition?/2" do
    test "pending -> starting is valid" do
      assert ContainerLifecyclePolicy.can_transition?(:pending, :starting)
    end

    test "starting -> running is valid" do
      assert ContainerLifecyclePolicy.can_transition?(:starting, :running)
    end

    test "running -> stopped is valid" do
      assert ContainerLifecyclePolicy.can_transition?(:running, :stopped)
    end

    test "stopped -> removed is valid" do
      assert ContainerLifecyclePolicy.can_transition?(:stopped, :removed)
    end

    test "forced removal from any state is valid" do
      for from <- [:pending, :starting, :running, :stopped] do
        assert ContainerLifecyclePolicy.can_transition?(from, :removed)
      end
    end

    test "running -> pending is invalid" do
      refute ContainerLifecyclePolicy.can_transition?(:running, :pending)
    end
  end

  describe "compensation_action/1" do
    test "container start failure compensates by deleting session" do
      assert :delete_session =
               ContainerLifecyclePolicy.compensation_action(:container_start_failed)
    end

    test "DB update failure compensates by stopping container" do
      assert :stop_and_remove_container =
               ContainerLifecyclePolicy.compensation_action(:db_update_failed)
    end

    test "unknown failures return none" do
      assert :none = ContainerLifecyclePolicy.compensation_action(:unknown)
    end
  end
end
