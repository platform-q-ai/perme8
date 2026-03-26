defmodule Agents.Pipeline.Application.UseCases.PipelineRunWorkflowsTest do
  use Agents.DataCase, async: false

  alias Agents.Pipeline.Application.UseCases.{GetPipelineStatus, RunStage, TriggerPipelineRun}
  alias Agents.Pipeline.Application.PipelineConfigBuilder
  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema

  defmodule PipelineRunRepoStub do
    def create_run(attrs, _repo \\ nil) do
      id = Ecto.UUID.generate()

      run =
        struct(
          PipelineRunSchema,
          Map.merge(
            %{id: id, inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()},
            attrs
          )
        )

      put_run(run)
      {:ok, run}
    end

    def get_run(id, _repo \\ nil) do
      case runs()[id] do
        nil -> {:error, :not_found}
        run -> {:ok, run}
      end
    end

    def update_run(id, attrs, _repo \\ nil) do
      case runs()[id] do
        nil ->
          {:error, :not_found}

        run ->
          updated = struct(run, Map.merge(Map.from_struct(run), attrs))
          put_run(updated)
          {:ok, updated}
      end
    end

    def count_active_for_stage(stage_id, _repo \\ nil) do
      runs()
      |> Map.values()
      |> Enum.count(
        &(&1.current_stage_id == stage_id and &1.status in ["running_stage", "awaiting_result"])
      )
    end

    def list_queued_for_stage(stage_id, _repo \\ nil) do
      runs()
      |> Map.values()
      |> Enum.filter(&(&1.queued_stage_id == stage_id and &1.status == "queued"))
      |> Enum.sort_by(& &1.enqueued_at)
    end

    def reset, do: Process.put({__MODULE__, :runs}, %{})

    defp runs, do: Process.get({__MODULE__, :runs}, %{})
    defp put_run(run), do: Process.put({__MODULE__, :runs}, Map.put(runs(), run.id, run))
  end

  defmodule StageExecutorStub do
    def execute(stage, context) do
      Process.get({__MODULE__, :execute}).(stage, context)
    end
  end

  defmodule EventBusStub do
    def emit(event) do
      events = Process.get({__MODULE__, :events}, [])
      Process.put({__MODULE__, :events}, events ++ [event])
      :ok
    end

    def events, do: Process.get({__MODULE__, :events}, [])
    def reset, do: Process.put({__MODULE__, :events}, [])
  end

  defmodule GateEvaluatorStub do
    def evaluate(stage, gates, context) do
      Process.get({__MODULE__, :evaluate}, fn _stage, _gates, _context ->
        {:ok, %{status: :passed, gate_results: [], metadata: %{}, reason: nil}}
      end).(stage, gates, context)
    end
  end

  defmodule SessionReopenerStub do
    def reopen(attrs) do
      Process.get({__MODULE__, :reopen}, fn payload ->
        send(self(), {:reopen_called, payload})
        :ok
      end).(attrs)
    end
  end

  defmodule TaskContextProviderStub do
    def get_task_context(task_id) do
      case Process.get({__MODULE__, :task, task_id}) do
        nil -> {:error, :task_not_found}
        task -> {:ok, task}
      end
    end
  end

  defmodule PipelineConfigRepoStub do
    def get_current do
      config =
        case Process.get({__MODULE__, :config}) do
          nil ->
            {:ok, config} = PipelineConfigBuilder.build(base_pipeline_map())

            Process.put({__MODULE__, :config}, config)
            config

          config ->
            config
        end

      {:ok, config}
    end

    defp base_pipeline_map do
      %{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "warm-pool",
              "type" => "warm_pool",
              "schedule" => %{"cron" => "*/5 * * * *"},
              "triggers" => ["on_ticket_play", "on_warm_pool"],
              "ticket_concurrency" => 1,
              "transitions" => [%{"on" => "passed", "to_stage" => "test"}],
              "warm_pool" => %{
                "target_count" => 2,
                "image" => "ghcr.io/platform-q-ai/perme8-runtime:latest",
                "readiness" => %{"strategy" => "command_success"}
              },
              "steps" => [
                %{"name" => "prestart", "run" => "scripts/warm_pool.sh", "depends_on" => []}
              ]
            },
            %{
              "id" => "test",
              "type" => "verification",
              "triggers" => ["on_session_complete", "on_pull_request"],
              "transitions" => [
                %{"on" => "failed", "to_stage" => "warm-pool", "reason" => "local_checks_failed"}
              ],
              "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
            },
            %{
              "id" => "merge-queue",
              "type" => "automation",
              "schedule" => %{"cron" => "*/10 * * * *"},
              "triggers" => ["on_merge_window"],
              "ticket_concurrency" => 0,
              "transitions" => [%{"on" => "passed", "to_stage" => "deploy"}],
              "steps" => [
                %{"name" => "merge-batch", "run" => "scripts/merge_queue.sh", "depends_on" => []}
              ]
            },
            %{
              "id" => "deploy",
              "type" => "automation",
              "triggers" => ["on_merge"],
              "steps" => [%{"name" => "deploy", "run" => "scripts/deploy.sh", "depends_on" => []}]
            }
          ]
        }
      }
    end
  end

  setup do
    PipelineRunRepoStub.reset()
    EventBusStub.reset()
    Process.delete({PipelineConfigRepoStub, :config})

    Process.put({SessionReopenerStub, :reopen}, fn payload ->
      send(self(), {:reopen_called, payload})
      :ok
    end)

    Application.put_env(:agents, :pipeline_config_repository, PipelineConfigRepoStub)

    on_exit(fn ->
      Application.delete_env(:agents, :pipeline_config_repository)
    end)

    :ok
  end

  test "trigger_pipeline_run selects verification stages for session completion" do
    assert {:ok, run} =
             TriggerPipelineRun.execute(
               %{
                 trigger_type: "on_session_complete",
                 trigger_reference: "task-1",
                 task_id: Ecto.UUID.generate()
               },
               auto_run: false,
               pipeline_run_repo: PipelineRunRepoStub
             )

    assert run.status == "idle"
    assert run.remaining_stage_ids == ["test"]
  end

  test "trigger_pipeline_run selects deploy stages for merge events" do
    assert {:ok, run} =
             TriggerPipelineRun.execute(
               %{
                 trigger_type: "on_merge",
                 trigger_reference: "12",
                 pull_request_number: 12
               },
               auto_run: false,
               pipeline_run_repo: PipelineRunRepoStub
             )

    assert run.remaining_stage_ids == ["deploy"]
  end

  test "trigger_pipeline_run persists pull request branch context" do
    event = %{
      event_type: "pipeline.pull_request_created",
      number: 14,
      source_branch: "feat/a",
      target_branch: "main"
    }

    assert {:ok, run} =
             TriggerPipelineRun.execute(
               %{
                 event: event,
                 trigger_type: "on_pull_request",
                 trigger_reference: "14",
                 pull_request_number: 14
               },
               auto_run: false,
               pipeline_run_repo: PipelineRunRepoStub
             )

    assert run.source_branch == "feat/a"
    assert run.target_branch == "main"
  end

  test "run_stage executes a stage and records stage change events" do
    Process.put({StageExecutorStub, :execute}, fn stage, context ->
      assert stage.id == "test"
      assert context["task_id"]
      assert context["source_branch"] == "feat/a"
      assert context["target_branch"] == "main"
      {:ok, %{output: "all green", exit_code: 0, metadata: %{}}}
    end)

    task_id = Ecto.UUID.generate()

    Process.put({TaskContextProviderStub, :task, task_id}, %{
      user_id: Ecto.UUID.generate(),
      container_id: nil,
      instruction: "ship it"
    })

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: task_id,
        task_id: task_id,
        source_branch: "feat/a",
        target_branch: "main",
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "passed"
    assert run.stage_results["test"].status == :passed

    assert Enum.map(EventBusStub.events(), &{&1.from_status, &1.to_status}) == [
             {"idle", "running_stage"},
             {"running_stage", "awaiting_result"},
             {"awaiting_result", "passed"}
           ]

    assert {:ok, fetched} =
             GetPipelineStatus.execute(run.id, pipeline_run_repo: PipelineRunRepoStub)

    assert fetched.status == "passed"
  end

  test "run_stage blocks when required gates do not pass" do
    Process.put({StageExecutorStub, :execute}, fn _stage, _context ->
      {:ok,
       %{output: "all green", exit_code: 0, metadata: %{"steps" => [%{"name" => "unit-tests"}]}}}
    end)

    Process.put({GateEvaluatorStub, :evaluate}, fn stage, _gates, _context ->
      assert stage.id == "test"

      {:ok,
       %{
         status: :blocked,
         gate_results: [],
         metadata: %{"gate_results" => []},
         reason: "approval_required"
       }}
    end)

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: "task-2",
        task_id: Ecto.UUID.generate(),
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "blocked"
    assert run.current_stage_id == "test"
    assert run.stage_results["test"].status == :blocked
  end

  test "run_stage queues when stage concurrency is exhausted" do
    {:ok, queued_config} =
      PipelineConfigBuilder.build(%{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "test",
              "type" => "verification",
              "triggers" => ["on_session_complete"],
              "ticket_concurrency" => 0,
              "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
            }
          ]
        }
      })

    Process.put({PipelineConfigRepoStub, :config}, queued_config)

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: "task-queue",
        task_id: Ecto.UUID.generate(),
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "queued"
    assert run.remaining_stage_ids == ["test"]

    assert {:ok, persisted} = PipelineRunRepoStub.get_run(created.id)
    assert persisted.status == "queued"
  end

  test "run_stage follows failure transitions back to a recovery stage" do
    {:ok, recovery_config} =
      PipelineConfigBuilder.build(%{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "test",
              "type" => "verification",
              "triggers" => ["on_session_complete"],
              "transitions" => [%{"on" => "failed", "to_stage" => "repair"}],
              "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
            },
            %{
              "id" => "repair",
              "type" => "automation",
              "steps" => [%{"name" => "repair", "run" => "scripts/repair.sh", "depends_on" => []}]
            }
          ]
        }
      })

    Process.put({PipelineConfigRepoStub, :config}, recovery_config)

    Process.put({StageExecutorStub, :execute}, fn stage, _context ->
      if stage.id == "test" do
        {:error, %{output: "tests failed", exit_code: 1, reason: :non_zero_exit, metadata: %{}}}
      else
        {:ok, %{output: "recovered", exit_code: 0, metadata: %{"steps" => []}}}
      end
    end)

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: "task-3",
        task_id: Ecto.UUID.generate(),
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "passed"
    assert run.stage_results["test"].status == :failed
    assert run.stage_results["repair"].status == :passed
  end

  test "run_stage reopens the task when session-complete verification fails" do
    Process.put({StageExecutorStub, :execute}, fn _stage, _context ->
      {:error, %{output: "tests failed", exit_code: 1, reason: :non_zero_exit, metadata: %{}}}
    end)

    {:ok, config_without_failure_transition} =
      PipelineConfigBuilder.build(%{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "test",
              "type" => "verification",
              "triggers" => ["on_session_complete"],
              "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
            }
          ]
        }
      })

    Process.put({PipelineConfigRepoStub, :config}, config_without_failure_transition)

    task_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    Process.put({TaskContextProviderStub, :task, task_id}, %{
      user_id: user_id,
      container_id: nil,
      instruction: "fix failures"
    })

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: task_id,
        task_id: task_id,
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "reopen_session"
    assert_receive {:reopen_called, %{task_id: ^task_id, user_id: ^user_id}}
  end

  test "run_stage surfaces reopen failures" do
    Process.put({StageExecutorStub, :execute}, fn _stage, _context ->
      {:error, %{output: "tests failed", exit_code: 1, reason: :non_zero_exit, metadata: %{}}}
    end)

    {:ok, config_without_failure_transition} =
      PipelineConfigBuilder.build(%{
        "version" => 1,
        "pipeline" => %{
          "name" => "perme8-core",
          "stages" => [
            %{
              "id" => "test",
              "type" => "verification",
              "triggers" => ["on_session_complete"],
              "steps" => [%{"name" => "unit-tests", "run" => "mix test", "depends_on" => []}]
            }
          ]
        }
      })

    Process.put({PipelineConfigRepoStub, :config}, config_without_failure_transition)

    Process.put({SessionReopenerStub, :reopen}, fn _payload ->
      {:error, :session_resume_failed}
    end)

    task_id = Ecto.UUID.generate()

    Process.put({TaskContextProviderStub, :task, task_id}, %{
      user_id: Ecto.UUID.generate(),
      container_id: nil,
      instruction: "fix failures"
    })

    {:ok, created} =
      PipelineRunRepoStub.create_run(%{
        trigger_type: "on_session_complete",
        trigger_reference: task_id,
        task_id: task_id,
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:error, {:reopen_session_failed, :session_resume_failed}} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               gate_evaluator: GateEvaluatorStub,
               task_context_provider: TaskContextProviderStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )
  end
end
