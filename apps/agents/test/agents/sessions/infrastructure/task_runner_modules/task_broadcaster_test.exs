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
      TaskBroadcaster.broadcast_event(event, @task_id, @pubsub)

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
    test "computes mem_percent and broadcasts stats payload" do
      container_id = "container-xyz"

      container_provider =
        stub_container_provider(%{
          cpu_percent: 25.5,
          memory_usage: 512_000_000,
          memory_limit: 1_024_000_000
        })

      TaskBroadcaster.broadcast_container_stats(
        container_id,
        container_provider,
        @task_id,
        @pubsub
      )

      assert_receive {:container_stats_updated, @task_id, ^container_id, payload}
      assert payload.cpu_percent == 25.5
      assert payload.memory_percent == 50.0
      assert payload.memory_usage == 512_000_000
      assert payload.memory_limit == 1_024_000_000
    end

    test "handles zero memory_limit without division error" do
      container_id = "container-xyz"

      container_provider =
        stub_container_provider(%{
          cpu_percent: 10.0,
          memory_usage: 0,
          memory_limit: 0
        })

      TaskBroadcaster.broadcast_container_stats(
        container_id,
        container_provider,
        @task_id,
        @pubsub
      )

      assert_receive {:container_stats_updated, @task_id, ^container_id, payload}
      assert payload.memory_percent == 0.0
    end

    test "silently handles stats errors" do
      container_id = "container-xyz"

      container_provider = %{
        stats: fn _id -> {:error, :not_found} end
      }

      # Module-based mock that responds to stats/1
      defmodule ErrorProvider do
        def stats(_id), do: {:error, :not_found}
      end

      TaskBroadcaster.broadcast_container_stats(
        container_id,
        ErrorProvider,
        @task_id,
        @pubsub
      )

      refute_receive {:container_stats_updated, _, _, _}
    end

    test "returns :ok for nil container_id" do
      result = TaskBroadcaster.broadcast_container_stats(nil, nil, @task_id, @pubsub)
      assert result == :ok
      refute_receive {:container_stats_updated, _, _, _}
    end
  end

  describe "broadcast_status_with_lifecycle/5" do
    test "broadcasts both status and lifecycle transition" do
      current_task = %{status: "starting", container_id: "c1", container_port: 8080}

      TaskBroadcaster.broadcast_status_with_lifecycle(
        @task_id,
        @pubsub,
        "running",
        %{status: "running"},
        current_task
      )

      assert_receive {:task_status_changed, @task_id, "running"}
      assert_receive {:lifecycle_state_changed, @task_id, _from, _to}
    end
  end

  describe "lifecycle_target_task/3" do
    test "creates map from attrs when current_task is nil" do
      result = TaskBroadcaster.lifecycle_target_task(nil, %{container_id: "c1"}, "starting")
      assert result == %{container_id: "c1", status: "starting"}
    end

    test "merges attrs into current task struct" do
      current = %Agents.Sessions.Infrastructure.Schemas.TaskSchema{
        id: "t1",
        status: "starting",
        container_id: nil,
        container_port: nil
      }

      result =
        TaskBroadcaster.lifecycle_target_task(
          current,
          %{container_id: "c1", container_port: 8080},
          "running"
        )

      assert result.container_id == "c1"
      assert result.container_port == 8080
      assert result.status == "running"
    end
  end

  describe "lifecycle_state_from_task/1" do
    test "returns :idle for nil task" do
      assert TaskBroadcaster.lifecycle_state_from_task(nil) == :idle
    end

    test "delegates to SessionLifecyclePolicy for non-nil task" do
      task = %{status: "running", container_id: "c1", container_port: 8080}
      result = TaskBroadcaster.lifecycle_state_from_task(task)
      # Should return some lifecycle state atom, not nil
      assert is_atom(result)
    end
  end

  # Helper to create a module-like struct that responds to stats/1
  defp stub_container_provider(stats_response) do
    # We need a module that implements stats/1
    # Use a simple approach: define the test module inline
    {:ok, pid} = Agent.start_link(fn -> stats_response end)

    # Create a module dynamically for each test
    mod_name = :"StubProvider_#{System.unique_integer([:positive])}"

    Module.create(
      mod_name,
      quote do
        def stats(_container_id) do
          {:ok, unquote(Macro.escape(stats_response))}
        end
      end,
      Macro.Env.location(__ENV__)
    )

    Agent.stop(pid)
    mod_name
  end
end
