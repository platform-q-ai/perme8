defmodule Agents.Sessions.Application.UseCases.CreateTask do
  @moduledoc """
  Use case for creating a new coding task.

  Validates the instruction, checks the queue concurrency limit,
  creates the task in the database, and either starts a TaskRunner
  immediately or queues the task if the concurrency limit is reached.
  """

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Events.{TaskCreated, TaskQueued}
  alias Agents.Sessions.Domain.Policies.QueuePolicy
  alias Agents.Sessions.Infrastructure.QueueManagerSupervisor

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_event_bus Perme8.Events.EventBus
  @default_queue_manager Agents.Sessions.Infrastructure.QueueManager

  @doc """
  Creates a new coding task.

  Checks the user's concurrency limit. If capacity is available, the task
  is created in "pending" status and a TaskRunner is started. If the limit
  is reached, the task is created in "queued" status with a queue position.

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
    queue_manager = Keyword.get(opts, :queue_manager, @default_queue_manager)

    with :ok <- validate_instruction(attrs) do
      user_id = attrs[:user_id] || attrs["user_id"]

      if should_queue?(user_id, task_repo, queue_manager) do
        create_queued_task(attrs, user_id, task_repo, event_bus)
      else
        create_and_start_task(attrs, task_repo, event_bus, opts)
      end
    end
  end

  defp should_queue?(user_id, task_repo, queue_manager) do
    case QueueManagerSupervisor.ensure_started(user_id) do
      {:ok, _pid} ->
        case queue_manager.check_concurrency(user_id) do
          :at_limit -> true
          :ok -> false
        end

      {:error, _reason} ->
        # If QueueManager can't start, don't block task creation
        false
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

  defp create_and_start_task(attrs, task_repo, event_bus, opts) do
    with {:ok, schema} <- task_repo.create_task(attrs),
         :ok <- start_runner(schema.id, task_repo, opts) do
      _ = emit_task_created(schema, event_bus)
      {:ok, Task.from_schema(schema)}
    end
  end

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp start_runner(task_id, task_repo, opts) do
    case Keyword.get(opts, :task_runner_starter) do
      nil ->
        :ok

      starter ->
        case starter.(task_id, opts) do
          {:ok, _pid} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "CreateTask: failed to start runner for task #{task_id}: #{inspect(reason)}"
            )

            mark_task_failed(task_id, task_repo, "Runner failed to start: #{inspect(reason)}")
            {:error, :runner_start_failed}
        end
    end
  end

  defp mark_task_failed(task_id, task_repo, error) do
    case task_repo.get_task(task_id) do
      nil -> :ok
      task -> task_repo.update_task_status(task, %{status: "failed", error: error})
    end
  end

  defp emit_task_created(schema, event_bus) do
    event_bus.emit(
      TaskCreated.new(%{
        aggregate_id: schema.id,
        actor_id: schema.user_id,
        task_id: schema.id,
        user_id: schema.user_id,
        instruction: schema.instruction
      })
    )
  end

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
end
