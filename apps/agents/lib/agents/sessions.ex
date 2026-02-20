defmodule Agents.Sessions do
  @moduledoc """
  Public API facade for the Sessions bounded context.

  Provides operations for managing coding tasks that run in
  ephemeral Docker containers with opencode.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Sessions.Domain,
      Agents.Sessions.Application,
      Agents.Sessions.Infrastructure,
      Identity.Repo
    ],
    exports: [
      {Domain.Entities.Task, []}
    ]

  alias Agents.Sessions.Application.UseCases.{CreateTask, CancelTask, GetTask, ListTasks}
  alias Agents.Sessions.Infrastructure.TaskRunnerSupervisor

  @doc """
  Creates a new coding task.

  Starts a Docker container, runs opencode, and streams events
  back via PubSub.

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
  - `{:error, :concurrent_limit_reached}` - When user already has an active task
  - `{:error, changeset}` - On validation error
  """
  @spec create_task(map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def create_task(attrs, opts \\ []) do
    opts = inject_task_runner_starter(opts)
    CreateTask.execute(attrs, opts)
  end

  @doc """
  Cancels a running task.

  Sends abort to the opencode session and stops the container.
  """
  @spec cancel_task(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def cancel_task(task_id, user_id, opts \\ []) do
    CancelTask.execute(task_id, user_id, opts)
  end

  @doc """
  Gets a task by ID with ownership check.
  """
  @spec get_task(String.t(), String.t(), keyword()) :: {:ok, struct()} | {:error, :not_found}
  def get_task(task_id, user_id, opts \\ []) do
    GetTask.execute(task_id, user_id, opts)
  end

  @doc """
  Lists tasks for a user, most recent first.
  """
  @spec list_tasks(String.t(), keyword()) :: [struct()]
  def list_tasks(user_id, opts \\ []) do
    ListTasks.execute(user_id, opts)
  end

  # Wire the real TaskRunnerSupervisor starter
  defp inject_task_runner_starter(opts) do
    if Keyword.has_key?(opts, :task_runner_starter) do
      opts
    else
      Keyword.put(opts, :task_runner_starter, fn task_id, runner_opts ->
        TaskRunnerSupervisor.start_child(task_id, runner_opts)
      end)
    end
  end
end
