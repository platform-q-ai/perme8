defmodule Agents.Sessions.Infrastructure.TaskRunner.TaskBroadcasterTest do
  use ExUnit.Case, async: true

  alias Agents.Sessions.Infrastructure.TaskRunner.TaskBroadcaster

  @task_id "test-task-123"
  @pubsub Perme8.Events.PubSub

  setup do
    Phoenix.PubSub.subscribe(@pubsub, "task:#{@task_id}")
    :ok
  end

  describe "broadcast_event/3" do
    test "broadcasts {:task_event, task_id, event}" do
      event = %{"type" => "message.part.updated", "data" => "hello"}
      TaskBroadcaster.broadcast_event(@task_id, event, @pubsub)

      assert_receive {:task_event, @task_id, ^event}
    end
  end

  describe "broadcast_status/3" do
    test "broadcasts {:task_status_changed, task_id, status}" do
      TaskBroadcaster.broadcast_status(@task_id, "running", @pubsub)

      assert_receive {:task_status_changed, @task_id, "running"}
    end
  end

  describe "broadcast_session_id_set/3" do
    test "broadcasts {:task_session_id_set, task_id, session_id}" do
      session_id = "session-abc"
      TaskBroadcaster.broadcast_session_id_set(@task_id, session_id, @pubsub)

      assert_receive {:task_session_id_set, @task_id, ^session_id}
    end
  end

  describe "broadcast_todo_update/3" do
    test "broadcasts {:todo_updated, task_id, items}" do
      items = [%{"id" => "1", "content" => "Do thing"}]
      TaskBroadcaster.broadcast_todo_update(@task_id, items, @pubsub)

      assert_receive {:todo_updated, @task_id, ^items}
    end
  end

  describe "broadcast_question_replied/2" do
    test "broadcasts question.replied event" do
      TaskBroadcaster.broadcast_question_replied(@task_id, @pubsub)

      assert_receive {:task_event, @task_id, %{"type" => "question.replied"}}
    end
  end

  describe "broadcast_question_rejected/2" do
    test "broadcasts question.rejected event" do
      TaskBroadcaster.broadcast_question_rejected(@task_id, @pubsub)

      assert_receive {:task_event, @task_id, %{"type" => "question.rejected"}}
    end
  end

  describe "broadcast_container_stats/4" do
    test "broadcasts pre-computed stats payload" do
      container_id = "container-xyz"

      payload = %{
        cpu_percent: 25.5,
        memory_percent: 50.0,
        memory_usage: 512_000_000,
        memory_limit: 1_024_000_000
      }

      TaskBroadcaster.broadcast_container_stats(
        @task_id,
        container_id,
        payload,
        @pubsub
      )

      assert_receive {:container_stats_updated, @task_id, ^container_id, ^payload}
    end
  end

  describe "broadcast_status_with_lifecycle/5" do
    test "broadcasts both status and lifecycle transition" do
      current_task = %{status: "starting", container_id: "c1", container_port: 8080}

      TaskBroadcaster.broadcast_status_with_lifecycle(
        @task_id,
        "running",
        %{status: "running"},
        current_task,
        @pubsub
      )

      assert_receive {:task_status_changed, @task_id, "running"}
      assert_receive {:lifecycle_state_changed, @task_id, _from, _to}
    end
  end
end
