defmodule Agents.Pipeline.Application.UseCases.PipelineRunWorkflowsTest do
  use Agents.DataCase, async: false

  alias Agents.Pipeline.Application.UseCases.{GetPipelineStatus, RunStage, TriggerPipelineRun}
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

  defmodule SessionReopenerStub do
    def reopen(attrs) do
      Process.get({__MODULE__, :reopen}, fn payload ->
        send(self(), {:reopen_called, payload})
        :ok
      end).(attrs)
    end
  end

  defmodule TaskRepoStub do
    def get_task(task_id) do
      Process.get({__MODULE__, :task, task_id})
    end
  end

  setup do
    PipelineRunRepoStub.reset()
    EventBusStub.reset()

    Process.put({SessionReopenerStub, :reopen}, fn payload ->
      send(self(), {:reopen_called, payload})
      :ok
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
        source_branch: "feat/a",
        target_branch: "main",
        remaining_stage_ids: ["test"],
        stage_results: %{}
      })

    assert {:ok, run} =
             RunStage.execute(created.id,
               pipeline_run_repo: PipelineRunRepoStub,
               stage_executor: StageExecutorStub,
               task_repo: TaskRepoStub,
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

    Process.put({SessionReopenerStub, :reopen}, fn _payload ->
      {:error, :session_resume_failed}
    end)

    task_id = Ecto.UUID.generate()

    Process.put({TaskRepoStub, :task, task_id}, %{
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
               task_repo: TaskRepoStub,
               event_bus: EventBusStub,
               session_reopener: SessionReopenerStub
             )
  end
end
