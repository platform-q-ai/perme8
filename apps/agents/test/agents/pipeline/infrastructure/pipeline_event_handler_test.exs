defmodule Agents.Pipeline.Infrastructure.PipelineEventHandlerTest do
  use ExUnit.Case, async: true

  alias Agents.Pipeline.Infrastructure.PipelineEventHandler
  alias Agents.Pipeline.Infrastructure.Schemas.PipelineRunSchema
  alias Agents.Sessions.Domain.Events.TaskCompleted
  alias Perme8.Events.TestEventBus

  defmodule StageExecutorStub do
    def execute(_stage, _context), do: {:ok, %{output: "ok", exit_code: 0, metadata: %{}}}
  end

  defmodule TaskContextProviderStub do
    def get_task_context(_task_id),
      do: {:ok, %{user_id: Ecto.UUID.generate(), container_id: nil, instruction: "rerun"}}
  end

  defmodule PipelineRunRepoStub do
    def create_run(attrs, _repo \\ nil) do
      id = Ecto.UUID.generate()
      run = struct(PipelineRunSchema, Map.merge(%{id: id}, attrs))
      Process.put({__MODULE__, :last_run}, run)
      {:ok, run}
    end

    def get_run(id, _repo \\ nil) do
      case Process.get({__MODULE__, :last_run}) do
        %{id: ^id} = run -> {:ok, run}
        _ -> {:error, :not_found}
      end
    end

    def update_run(id, attrs, _repo \\ nil) do
      case Process.get({__MODULE__, :last_run}) do
        %{id: ^id} = run ->
          updated = struct(run, Map.merge(Map.from_struct(run), attrs))
          Process.put({__MODULE__, :last_run}, updated)
          {:ok, updated}

        _ ->
          {:error, :not_found}
      end
    end
  end

  setup do
    TestEventBus.start_global()

    Application.put_env(:agents, :pipeline_stage_executor, StageExecutorStub)
    Application.put_env(:agents, :pipeline_event_bus, TestEventBus)
    Application.put_env(:agents, :pipeline_run_repository, PipelineRunRepoStub)
    Application.put_env(:agents, :pipeline_task_context_provider, TaskContextProviderStub)

    on_exit(fn ->
      Application.delete_env(:agents, :pipeline_stage_executor)
      Application.delete_env(:agents, :pipeline_event_bus)
      Application.delete_env(:agents, :pipeline_run_repository)
      Application.delete_env(:agents, :pipeline_task_context_provider)
    end)

    :ok
  end

  test "task completion creates and executes a pipeline run" do
    event =
      TaskCompleted.new(%{
        aggregate_id: Ecto.UUID.generate(),
        actor_id: Ecto.UUID.generate(),
        task_id: Ecto.UUID.generate(),
        user_id: Ecto.UUID.generate(),
        target_user_id: Ecto.UUID.generate()
      })

    assert :ok = PipelineEventHandler.handle_event(event)

    assert %PipelineRunSchema{} = run = Process.get({PipelineRunRepoStub, :last_run})
    assert run.status == "passed"
  end
end
