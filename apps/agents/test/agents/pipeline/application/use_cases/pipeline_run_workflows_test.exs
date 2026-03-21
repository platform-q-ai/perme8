defmodule Agents.Pipeline.Application.UseCases.PipelineRunWorkflowsTest do
  use Agents.DataCase, async: true

  alias Agents.Pipeline.Application.UseCases.{GetPipelineStatus, RunStage, TriggerPipelineRun}
  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema
  alias Perme8.Events.TestEventBus

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

    def reset, do: Process.put({__MODULE__, :runs}, %{})

    defp runs, do: Process.get({__MODULE__, :runs}, %{})
    defp put_run(run), do: Process.put({__MODULE__, :runs}, Map.put(runs(), run.id, run))
  end

  defmodule StageExecutorStub do
    def execute(stage, context) do
      Process.get({__MODULE__, :execute}).(stage, context)
    end
  end

  defmodule SessionReopenerStub do
    def reopen(attrs) do
      send(self(), {:reopen_called, attrs})
      :ok
    end
  end

  defmodule TaskRepoStub do
    def get_task(task_id) do
      Process.get({__MODULE__, :task, task_id})
    end
  end

  setup do
    TestEventBus.start_global()
    PipelineRunRepoStub.reset()
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

  test "run_stage executes a stage and records stage change events" do
    Process.put({StageExecutorStub, :execute}, fn stage, context ->
      assert stage.id == "test"
      assert context["task_id"]
      {:ok, %{output: "all green", exit_code: 0, metadata: %{}}}
    end)

    task_id = Ecto.UUID.generate()

    Process.put({TaskRepoStub, :task, task_id}, %{
      user_id: Ecto.UUID.generate(),
      container_id: nil,
      instruction: "ship it"
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
               task_repo: TaskRepoStub,
               event_bus: TestEventBus,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "passed"
    assert run.stage_results["test"].status == :passed

    assert Enum.map(TestEventBus.get_events(), &{&1.from_status, &1.to_status}) == [
             {"idle", "running_stage"},
             {"running_stage", "awaiting_result"},
             {"awaiting_result", "passed"}
           ]

    assert {:ok, fetched} =
             GetPipelineStatus.execute(run.id, pipeline_run_repo: PipelineRunRepoStub)

    assert fetched.status == "passed"
  end

  test "run_stage reopens the task when session-complete verification fails" do
    Process.put({StageExecutorStub, :execute}, fn _stage, _context ->
      {:error, %{output: "tests failed", exit_code: 1, reason: :non_zero_exit, metadata: %{}}}
    end)

    task_id = Ecto.UUID.generate()
    user_id = Ecto.UUID.generate()

    Process.put({TaskRepoStub, :task, task_id}, %{
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
               task_repo: TaskRepoStub,
               event_bus: TestEventBus,
               session_reopener: SessionReopenerStub
             )

    assert run.status == "reopen_session"
    assert_receive {:reopen_called, %{task_id: ^task_id, user_id: ^user_id}}
  end
end
