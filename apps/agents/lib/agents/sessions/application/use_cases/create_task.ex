defmodule Agents.Sessions.Application.UseCases.CreateTask do
  @moduledoc """
  Use case for creating a new coding task.

  Validates the instruction, checks the concurrent task limit,
  creates the task in the database, and starts a TaskRunner.
  """

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Domain.Entities.Task

  @default_task_repo Agents.Sessions.Infrastructure.Repositories.TaskRepository

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
  - `{:error, :concurrent_limit_reached}` - When user has too many active tasks
  - `{:error, changeset}` - On validation error
  """
  def execute(attrs, opts \\ []) do
    task_repo = Keyword.get(opts, :task_repo, @default_task_repo)

    with :ok <- validate_instruction(attrs),
         :ok <- check_concurrent_limit(attrs.user_id, task_repo),
         {:ok, schema} <- task_repo.create_task(attrs) do
      start_runner(schema.id, opts)
      {:ok, Task.from_schema(schema)}
    end
  end

  defp validate_instruction(%{instruction: instruction})
       when is_binary(instruction) and instruction != "" do
    :ok
  end

  defp validate_instruction(_), do: {:error, :instruction_required}

  defp check_concurrent_limit(user_id, task_repo) do
    count = task_repo.running_task_count_for_user(user_id)
    max = SessionsConfig.max_concurrent_tasks()

    if count < max, do: :ok, else: {:error, :concurrent_limit_reached}
  end

  defp start_runner(task_id, opts) do
    case Keyword.get(opts, :task_runner_starter) do
      nil -> :ok
      starter -> starter.(task_id, opts)
    end
  end
end
