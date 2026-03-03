defmodule Agents.Sessions.Application.UseCases.CreateTask do
  @moduledoc """
  Use case for creating a new coding task.

  Validates the instruction, then enqueues the task in the database.
  Queue orchestration is responsible for warming and promotion into processing.
  """

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Events.TaskQueued
  alias Agents.Sessions.Domain.Policies.QueuePolicy

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Creates a new coding task.

  Task creation always inserts in "queued" status with a queue position.

  ## Parameters
  - `attrs` - Map with:
    - `:instruction` - (required) The coding instruction
    - `:user_id` - (required) The user creating the task
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module (default: TaskRepository)
    - `:task_runner_starter` - Function to start a TaskRunner (default: TaskRunnerSupervisor.start_child)
    - `:queue_manager` - QueueManager module (default: QueueManager)

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, changeset}` - On validation error
  """
  @spec execute(map(), keyword()) ::
          {:ok, Agents.Sessions.Domain.Entities.Task.t()} | {:error, term()}
  def execute(attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)
    concurrency_lock = Keyword.get(opts, :concurrency_lock, &no_concurrency_lock/2)

    with :ok <- validate_instruction(attrs) do
      user_id = attrs[:user_id] || attrs["user_id"]

      concurrency_lock.(user_id, fn ->
        create_queued_task(attrs, user_id, task_repo, event_bus)
      end)
    end
  end

  defp create_queued_task(attrs, user_id, task_repo, event_bus) do
    max_pos = task_repo.get_max_queue_position(user_id)
    queue_position = QueuePolicy.next_queue_position(max_pos)

    queued_attrs =
      Map.merge(attrs, %{
        status: "queued",
        queue_position: queue_position,
        queued_at: DateTime.utc_now()
      })

    case task_repo.create_task(queued_attrs) do
      {:ok, schema} ->
        _ = emit_task_queued(schema, queue_position, event_bus)
        {:ok, Task.from_schema(schema)}

      error ->
        error
    end
  end

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp emit_task_queued(schema, queue_position, event_bus) do
    event_bus.emit(
      TaskQueued.new(%{
        aggregate_id: schema.id,
        actor_id: schema.user_id,
        task_id: schema.id,
        user_id: schema.user_id,
        queue_position: queue_position
      })
    )
  end

  defp no_concurrency_lock(_user_id, fun), do: fun.()
end
