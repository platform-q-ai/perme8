defmodule Agents.Sessions.Infrastructure.TaskRunnerTest do
  use Agents.DataCase

  alias Agents.Sessions.Infrastructure.TaskRunner
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Repo

  import Agents.Test.AccountsFixtures

  # ---------------------------------------------------------------------------
  # Stub modules injected via opts
  # ---------------------------------------------------------------------------

  defmodule StubTaskRepo do
    @moduledoc false
    def get_task(task_id) do
      Agents.Repo.get(TaskSchema, task_id)
    end

    def update_task_status(task, attrs) do
      task
      |> TaskSchema.status_changeset(attrs)
      |> Agents.Repo.update()
    end
  end

  defmodule StubEventBus do
    @moduledoc false
    def emit(_event), do: :ok
  end

  defmodule StubOpencode do
    @moduledoc false
    def health(_url), do: :ok
    def create_session(_url, _opts), do: {:ok, %{"id" => "sess-1"}}
    def subscribe(_url, _opts), do: {:ok, self()}
    def subscribe_events(_url, _pid), do: {:ok, self()}
    def send_prompt_async(_url, _session_id, _parts, _opts), do: :ok
    def reply_question(_url, _req_id, _answers, _opts), do: :ok
    def reject_question(_url, _req_id, _opts), do: :ok
  end

  # ---------------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------------

  defp insert_task(user, attrs \\ %{}) do
    default = %{
      user_id: user.id,
      instruction: "test instruction",
      status: "pending"
    }

    %TaskSchema{}
    |> TaskSchema.changeset(Map.merge(default, attrs))
    |> Repo.insert!()
  end

  defp common_opts(overrides) do
    Keyword.merge(
      [
        task_repo: StubTaskRepo,
        opencode_client: StubOpencode,
        event_bus: StubEventBus,
        pubsub: Perme8.Events.PubSub,
        queue_terminal_notifier: fn _, _, _ -> :ok end
      ],
      overrides
    )
  end

  # ---------------------------------------------------------------------------
  # broadcast_container_stats/1
  # ---------------------------------------------------------------------------

  describe "broadcast_container_stats on flush" do
    test "broadcasts container stats via PubSub when output flush fires" do
      user = user_fixture()
      task = insert_task(user)

      stats_payload = %{cpu_percent: 12.5, memory_usage: 500_000, memory_limit: 1_000_000}

      stub_container_provider =
        Module.concat(__MODULE__, :"StatsProvider#{System.unique_integer([:positive])}")

      {:module, provider_mod, _, _} =
        defmodule stub_container_provider do
          def start(_image, _opts),
            do: {:ok, %{container_id: "stats-container", port: 9999}}

          def stop(_cid, _opts \\ []), do: :ok
          def remove(_cid, _opts \\ []), do: :ok
          def restart(_cid, _opts \\ []), do: {:ok, %{port: 9999}}
          def status(_cid, _opts \\ []), do: {:ok, :running}

          def stats(_cid, _opts \\ []),
            do: {:ok, %{cpu_percent: 12.5, memory_usage: 500_000, memory_limit: 1_000_000}}

          def prepare_fresh_start(_cid, _opts \\ []), do: :ok
        end

      # Subscribe to the task PubSub topic
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

      {:ok, pid} =
        TaskRunner.start_link({task.id, common_opts(container_provider: provider_mod)})

      # The runner will send :start_container to itself, which triggers container start,
      # then health check, session creation, prompt send, and a flush timer.
      # We need to wait for the task to reach "running" status and a flush to happen.
      # The broadcast_container_stats fires on :flush_output and when prompt is sent.

      # We should receive the stats broadcast since we're subscribed
      assert_receive {:container_stats_updated, _task_id, "stats-container", payload}, 5_000

      assert payload.cpu_percent == 12.5
      # mem_percent = 500_000 / 1_000_000 * 100 = 50.0
      assert payload.memory_percent == 50.0
      assert payload.memory_usage == 500_000
      assert payload.memory_limit == 1_000_000

      # Clean up
      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end

    test "does not crash when container stats returns error" do
      user = user_fixture()
      task = insert_task(user)

      stub_container_provider =
        Module.concat(__MODULE__, :"ErrorStatsProvider#{System.unique_integer([:positive])}")

      {:module, provider_mod, _, _} =
        defmodule stub_container_provider do
          def start(_image, _opts),
            do: {:ok, %{container_id: "err-stats-container", port: 9999}}

          def stop(_cid, _opts \\ []), do: :ok
          def remove(_cid, _opts \\ []), do: :ok
          def restart(_cid, _opts \\ []), do: {:ok, %{port: 9999}}
          def status(_cid, _opts \\ []), do: {:ok, :running}
          def stats(_cid, _opts \\ []), do: {:error, :not_found}
          def prepare_fresh_start(_cid, _opts \\ []), do: :ok
        end

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

      {:ok, pid} =
        TaskRunner.start_link({task.id, common_opts(container_provider: provider_mod)})

      # Wait for the task to attempt running — it should not crash even with stats error.
      # We should receive task_status_changed but NOT container_stats_updated.
      assert_receive {:task_status_changed, _, "running"}, 5_000
      refute_receive {:container_stats_updated, _, _, _}, 500

      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end

    test "broadcasts lifecycle_state_changed alongside status broadcasts" do
      user = user_fixture()
      task = insert_task(user)

      stub_container_provider =
        Module.concat(__MODULE__, :"LifecycleStatsProvider#{System.unique_integer([:positive])}")

      {:module, provider_mod, _, _} =
        defmodule stub_container_provider do
          def start(_image, _opts), do: {:ok, %{container_id: "lifecycle-container", port: 9999}}
          def stop(_cid, _opts \\ []), do: :ok
          def remove(_cid, _opts \\ []), do: :ok
          def restart(_cid, _opts \\ []), do: {:ok, %{port: 9999}}
          def status(_cid, _opts \\ []), do: {:ok, :running}

          def stats(_cid, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          def prepare_fresh_start(_cid, _opts \\ []), do: :ok
        end

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

      {:ok, pid} =
        TaskRunner.start_link({task.id, common_opts(container_provider: provider_mod)})

      task_id = task.id
      assert_receive {:lifecycle_state_changed, ^task_id, :pending, :starting}, 5_000
      assert_receive {:lifecycle_state_changed, ^task_id, :starting, :running}, 5_000

      if Process.alive?(pid), do: GenServer.stop(pid, :normal)
    end
  end

  # ---------------------------------------------------------------------------
  # Subtask cache format round-trip
  # ---------------------------------------------------------------------------

  describe "subtask cache format round-trip" do
    test "subtask cache entry decodes correctly through EventProcessor" do
      alias AgentsWeb.SessionsLive.EventProcessor

      # Build the cache entry that TaskRunner would produce
      entry = %{
        "type" => "subtask",
        "id" => "subtask-msg-1",
        "agent" => "explore",
        "description" => "Research spike",
        "prompt" => "Explore the codebase",
        "status" => "running"
      }

      # Encode as JSON (simulating DB persistence)
      json = Jason.encode!([entry])

      # Decode through EventProcessor (simulating LiveView mount/reconnect)
      parts = EventProcessor.decode_cached_output(json)

      assert [
               {:subtask, "subtask-msg-1",
                %{
                  agent: "explore",
                  description: "Research spike",
                  prompt: "Explore the codebase",
                  status: :done
                }}
             ] = parts
    end
  end

  # ---------------------------------------------------------------------------
  # Fresh warm start preparation failure
  # ---------------------------------------------------------------------------

  describe "prepare_fresh_start failure" do
    test "fails task with sanitized message when container repo sync fails (exit 1)" do
      user = user_fixture()
      task = insert_task(user)

      stub_container_provider =
        Module.concat(
          __MODULE__,
          :"FreshStartFailProvider#{System.unique_integer([:positive])}"
        )

      {:module, provider_mod, _, _} =
        defmodule stub_container_provider do
          def start(_image, _opts),
            do: {:ok, %{container_id: "fresh-fail-container", port: 9999}}

          def stop(_cid, _opts \\ []), do: :ok
          def remove(_cid, _opts \\ []), do: :ok

          def restart(_cid, _opts \\ []),
            do: {:ok, %{port: 9999}}

          def status(_cid, _opts \\ []), do: {:ok, :running}

          def stats(_cid, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          def prepare_fresh_start(_cid, _opts \\ []),
            do: {:error, {:docker_prepare_fresh_start_failed, 1, "sync output"}}
        end

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

      # Monitor before start so we don't miss the exit
      {:ok, pid} =
        TaskRunner.start_link(
          {task.id,
           common_opts(
             container_provider: provider_mod,
             prewarmed_container_id: "fresh-fail-container",
             fresh_warm_container: true
           )}
        )

      ref = Process.monitor(pid)

      # The runner takes the prewarmed container path:
      #   restart_prewarmed_container -> wait_for_health_fresh -> prepare_fresh_start
      # prepare_fresh_start calls container_provider.prepare_fresh_start, which returns
      # {:error, {:docker_prepare_fresh_start_failed, 1, "sync output"}}
      # This should cause the task to fail with the sanitized message.

      assert_receive {:task_status_changed, _, "failed"}, 5_000
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000

      # Verify task in DB
      updated_task = Repo.get!(TaskSchema, task.id)
      assert updated_task.status == "failed"

      assert updated_task.error ==
               "Fresh warm start preparation failed: container repo sync failed (exit 1)"
    end

    test "fails task with sanitized message when auth refresh fails" do
      user = user_fixture()
      task = insert_task(user)

      stub_container_provider =
        Module.concat(
          __MODULE__,
          :"AuthFailProvider#{System.unique_integer([:positive])}"
        )

      {:module, provider_mod, _, _} =
        defmodule stub_container_provider do
          def start(_image, _opts),
            do: {:ok, %{container_id: "auth-fail-container", port: 9999}}

          def stop(_cid, _opts \\ []), do: :ok
          def remove(_cid, _opts \\ []), do: :ok
          def restart(_cid, _opts \\ []), do: {:ok, %{port: 9999}}
          def status(_cid, _opts \\ []), do: {:ok, :running}

          def stats(_cid, _opts \\ []),
            do: {:ok, %{cpu_percent: 0.0, memory_usage: 0, memory_limit: 0}}

          # prepare_fresh_start succeeds — auth refresh will fail
          def prepare_fresh_start(_cid, _opts \\ []), do: :ok
        end

      stub_auth_refresher =
        Module.concat(
          __MODULE__,
          :"FailAuthRefresher#{System.unique_integer([:positive])}"
        )

      {:module, auth_mod, _, _} =
        defmodule stub_auth_refresher do
          def refresh_auth(_base_url, _opencode_client),
            do: {:error, {:auth_refresh_failed, :github}}
        end

      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

      {:ok, pid} =
        TaskRunner.start_link(
          {task.id,
           common_opts(
             container_provider: provider_mod,
             auth_refresher: auth_mod,
             prewarmed_container_id: "auth-fail-container",
             fresh_warm_container: true
           )}
        )

      ref = Process.monitor(pid)

      assert_receive {:task_status_changed, _, "failed"}, 5_000
      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000

      updated_task = Repo.get!(TaskSchema, task.id)
      assert updated_task.status == "failed"

      assert updated_task.error ==
               "Fresh warm start preparation failed: auth refresh failed"
    end
  end

  describe "session event isolation" do
    defmodule NoopTaskRepo do
      @moduledoc false
      def get_task(_task_id), do: nil
      def update_task_status(_task, _attrs), do: :ok
    end

    defp base_runner_state(overrides \\ %{}) do
      Map.merge(
        %TaskRunner{
          task_id: "task-#{System.unique_integer([:positive])}",
          session_id: "parent-sess-1",
          pubsub: Perme8.Events.PubSub,
          task_repo: NoopTaskRepo,
          event_bus: StubEventBus,
          queue_terminal_notifier: fn _, _, _ -> :ok end,
          output_parts: []
        },
        overrides
      )
    end

    test "parent session event is processed normally when event has no sessionID" do
      state = base_runner_state()
      task_id = state.task_id
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task_id}")

      event = %{
        "type" => "message.part.updated",
        "properties" => %{"part" => %{"type" => "text", "id" => "text-1", "text" => "hello"}}
      }

      assert {:noreply, new_state} = TaskRunner.handle_info({:opencode_event, event}, state)
      assert_receive {:task_event, ^task_id, ^event}

      assert Enum.any?(new_state.output_parts, fn part ->
               part["id"] == "text-1" and part["text"] == "hello"
             end)
    end

    test "child session session.status idle does not trigger task completion" do
      state =
        base_runner_state(%{
          was_running: true,
          child_session_ids: %{"child-sess-1" => "subtask-msg-1"}
        })

      event = %{
        "type" => "session.status",
        "properties" => %{"sessionID" => "child-sess-1", "status" => %{"type" => "idle"}}
      }

      assert {:noreply, _new_state} = TaskRunner.handle_info({:opencode_event, event}, state)
    end

    test "parent session session.status idle triggers task completion" do
      state = base_runner_state(%{was_running: true})

      event = %{
        "type" => "session.status",
        "properties" => %{"sessionID" => "parent-sess-1", "status" => %{"type" => "idle"}}
      }

      assert {:stop, :normal, _new_state} =
               TaskRunner.handle_info({:opencode_event, event}, state)
    end

    test "event with unknown session ID is skipped for caching" do
      state = base_runner_state(%{output_parts: [%{"id" => "keep-1", "type" => "text"}]})
      task_id = state.task_id
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task_id}")

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "sessionID" => "unknown-sess",
          "part" => %{"type" => "text", "id" => "child-text", "text" => "child output"}
        }
      }

      assert {:noreply, new_state} = TaskRunner.handle_info({:opencode_event, event}, state)
      assert_receive {:task_event, ^task_id, ^event}
      assert new_state.output_parts == state.output_parts
    end

    test "subtask part event registers child session ID" do
      state = base_runner_state()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{
            "type" => "subtask",
            "messageID" => "msg-1",
            "sessionID" => "child-sess-1"
          }
        }
      }

      assert {:noreply, new_state} = TaskRunner.handle_info({:opencode_event, event}, state)
      assert new_state.child_session_ids == %{"child-sess-1" => "subtask-msg-1"}
    end

    test "event with no sessionID is treated as parent session" do
      state = base_runner_state()

      event = %{
        "type" => "message.part.updated",
        "properties" => %{
          "part" => %{"type" => "reasoning", "id" => "reason-1", "text" => "thinking"}
        }
      }

      assert {:noreply, new_state} = TaskRunner.handle_info({:opencode_event, event}, state)

      assert Enum.any?(new_state.output_parts, fn part ->
               part["id"] == "reason-1" and part["type"] == "reasoning"
             end)
    end
  end
end
