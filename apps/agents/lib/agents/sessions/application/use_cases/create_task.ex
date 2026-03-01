defmodule Agents.Sessions.Application.UseCases.CreateTask do
  @moduledoc """
  Use case for creating a new coding task.

  Validates the instruction, checks the concurrent task limit,
  creates the task in the database, and starts a TaskRunner.
  """

  alias Agents.Sessions.Domain.Entities.Task
  alias Agents.Sessions.Domain.Events.TaskCreated

  require Logger

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository
  @default_event_bus Perme8.Events.EventBus

  @doc """
  Creates a new coding task.

  ## Parameters
  - `attrs` - Map with:
    - `:instruction` - (required) The coding instruction
    - `:user_id` - (required) The user creating the task
  - `opts` - Keyword list with:
    - `:task_repo` - Repository module (default: TaskRepository)
    - `:task_runner_starter` - Function to start a TaskRunner (default: TaskRunnerSupervisor.start_child)

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, changeset}` - On validation error
  """
  def execute(attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)
    event_bus = Keyword.get(opts, :event_bus, @default_event_bus)

    with :ok <- validate_instruction(attrs),
         {:ok, schema} <- task_repo.create_task(attrs),
         :ok <- start_runner(schema.id, task_repo, opts) do
      emit_task_created(schema, event_bus)
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
end
