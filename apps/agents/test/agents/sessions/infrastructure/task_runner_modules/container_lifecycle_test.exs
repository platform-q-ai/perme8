defmodule Agents.Sessions.Infrastructure.TaskRunner.ContainerLifecycleUnitTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.ContainerLifecycle

  describe "should_reconnect_sse?/6" do
    test "returns true when conditions are met" do
      pid = self()

      assert ContainerLifecycle.should_reconnect_sse?(
               pid,
               false,
               :running,
               "session-1",
               8080,
               pid
             )
    end

    test "returns false when different pid" do
      other_pid = spawn(fn -> :ok end)

      refute ContainerLifecycle.should_reconnect_sse?(
               self(),
               false,
               :running,
               "session-1",
               8080,
               other_pid
             )
    end

    test "returns false when already reconnecting" do
      pid = self()

      refute ContainerLifecycle.should_reconnect_sse?(
               pid,
               true,
               :running,
               "session-1",
               8080,
               pid
             )
    end

    test "returns false when not in active status" do
      pid = self()

      refute ContainerLifecycle.should_reconnect_sse?(
               pid,
               false,
               :starting,
               "session-1",
               8080,
               pid
             )
    end

    test "returns false when no session_id" do
      pid = self()

      refute ContainerLifecycle.should_reconnect_sse?(
               pid,
               false,
               :running,
               nil,
               8080,
               pid
             )
    end
  end

  describe "current_sse_process?/2" do
    test "returns true when pids match" do
      pid = self()
      assert ContainerLifecycle.current_sse_process?(pid, pid)
    end

    test "returns false when pids differ" do
      other = spawn(fn -> :ok end)
      refute ContainerLifecycle.current_sse_process?(self(), other)
    end

    test "returns false for nil" do
      refute ContainerLifecycle.current_sse_process?(nil, nil)
    end
  end

  describe "task_active_for_reconnect?/3" do
    test "returns true for :running with session and port" do
      assert ContainerLifecycle.task_active_for_reconnect?(:running, "s1", 8080)
    end

    test "returns true for :prompting with session and port" do
      assert ContainerLifecycle.task_active_for_reconnect?(:prompting, "s1", 8080)
    end

    test "returns false for :starting" do
      refute ContainerLifecycle.task_active_for_reconnect?(:starting, "s1", 8080)
    end

    test "returns false without session_id" do
      refute ContainerLifecycle.task_active_for_reconnect?(:running, nil, 8080)
    end

    test "returns false without container_port" do
      refute ContainerLifecycle.task_active_for_reconnect?(:running, "s1", nil)
    end
  end
end
