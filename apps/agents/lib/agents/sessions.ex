defmodule Agents.Sessions do
  @moduledoc """
  Public API facade for the Sessions bounded context.

  Provides operations for managing coding tasks that run in
  ephemeral Docker containers with opencode.

  Sessions are groups of tasks sharing a container_id.
  """

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Sessions.Domain,
      Agents.Sessions.Application,
      Agents.Sessions.Infrastructure,
      Agents.Repo
    ],
    exports: [
      {Domain.Entities.Task, []}
    ]

  alias Agents.Sessions.Application.UseCases.{
    CreateTask,
    CancelTask,
    DeleteTask,
    DeleteSession,
    ResumeTask,
    GetTask,
    ListTasks
  }

  alias Agents.Sessions.Infrastructure.TaskRunnerSupervisor

  @doc """
  Creates a new coding task.

  Starts a Docker container, runs opencode, and streams events
  back via PubSub.

  ## Returns
  - `{:ok, task}` - Domain entity on success
  - `{:error, :instruction_required}` - When instruction is blank
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
  Deletes a task record from the database.

  Does NOT remove the Docker container. Use `delete_session/3` to
  remove the container and all associated tasks.
  """
  @spec delete_task(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_task(task_id, user_id, opts \\ []) do
    DeleteTask.execute(task_id, user_id, opts)
  end

  @doc """
  Deletes an entire session: removes the Docker container and all
  tasks sharing the given container_id.
  """
  @spec delete_session(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def delete_session(container_id, user_id, opts \\ []) do
    DeleteSession.execute(container_id, user_id, opts)
  end

  @doc """
  Resumes a session with a follow-up instruction.

  Creates a new task linked to the parent, reuses the same container
  and opencode session.
  """
  @spec resume_task(String.t(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def resume_task(parent_task_id, attrs, opts \\ []) do
    opts = inject_task_runner_starter(opts)
    ResumeTask.execute(parent_task_id, attrs, opts)
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

  @doc """
  Lists sessions (grouped by container_id) for a user.

  Returns a list of maps with :container_id, :title, :task_count,
  :latest_status, :latest_at, :created_at.
  """
  @spec list_sessions(String.t(), keyword()) :: [map()]
  def list_sessions(user_id, opts \\ []) do
    task_repo =
      Keyword.get(
        opts,
        :task_repo,
        Agents.Sessions.Infrastructure.Repositories.TaskRepository
      )

    task_repo.list_sessions_for_user(user_id, opts)
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
