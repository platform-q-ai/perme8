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
    RefreshAuthAndResume,
    ResumeTask,
    GetTask,
    ListTasks
  }

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Infrastructure.QueueManager
  alias Agents.Sessions.Infrastructure.QueueManagerSupervisor
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
    opts = inject_queue_checker(opts)
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

  Reuses the existing task record and resets status to "pending".
  The original instruction remains the session title/context, while the
  follow-up instruction is sent as the resumed prompt.
  The container and opencode session are restarted.
  Todos and output history are preserved across the session lifetime.
  """
  @spec resume_task(String.t(), map(), keyword()) :: {:ok, struct()} | {:error, term()}
  def resume_task(task_id, attrs, opts \\ []) do
    opts = inject_task_runner_starter(opts)
    ResumeTask.execute(task_id, attrs, opts)
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
  :latest_status, :latest_at, :created_at, :started_at, :completed_at,
  and :session_summary.
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

  @doc """
  Returns the default Docker image name for sessions.
  """
  @spec default_image() :: String.t()
  def default_image do
    SessionsConfig.image()
  end

  @doc """
  Returns the list of available Docker images for sessions.

  Each entry is a map with `:name` and `:label`.
  """
  @spec available_images() :: [map()]
  def available_images do
    SessionsConfig.available_images()
  end

  @doc """
  Returns a human-readable label for a Docker image name.
  """
  @spec image_label(String.t()) :: String.t()
  def image_label(image_name) do
    case Enum.find(available_images(), &(&1.name == image_name)) do
      %{label: label} -> label
      _ -> image_name
    end
  end

  @doc """
  Returns CPU and memory stats for a running container.

  ## Returns
  - `{:ok, %{cpu_percent: float(), memory_usage: integer(), memory_limit: integer()}}`
  - `{:error, term()}` if the container is not running or stats unavailable
  """
  @spec get_container_stats(String.t(), keyword()) :: {:ok, map()} | {:error, term()}
  def get_container_stats(container_id, opts \\ []) do
    container_provider =
      Keyword.get(
        opts,
        :container_provider,
        Agents.Sessions.Infrastructure.Adapters.DockerAdapter
      )

    container_provider.stats(container_id)
  end

  @doc """
  Answers a question posed by the AI assistant during a task.

  Forwards the answer to the TaskRunner GenServer which calls the
  opencode question reply API.

  `answers` is a list of lists of strings — one list of selected labels
  per question. E.g. `[["Option A"], ["Option B", "Option C"]]`
  """
  @spec answer_question(String.t(), String.t(), [[String.t()]]) :: :ok | {:error, term()}
  def answer_question(task_id, request_id, answers) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.call(pid, {:answer_question, request_id, answers})
      [] -> {:error, :task_not_running}
    end
  end

  @doc """
  Rejects/dismisses a question posed by the AI assistant during a task.
  """
  @spec reject_question(String.t(), String.t()) :: :ok | {:error, term()}
  def reject_question(task_id, request_id) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.call(pid, {:reject_question, request_id})
      [] -> {:error, :task_not_running}
    end
  end

  @doc """
  Sends a message to a running session via prompt_async.

  The message is queued by opencode and processed after the agent finishes
  its current work. Does not interrupt or abort the current operation.
  """
  @spec send_message(String.t(), String.t()) :: :ok | {:error, term()}
  def send_message(task_id, message) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.call(pid, {:send_message, message})
      [] -> {:error, :task_not_running}
    end
  end

  @doc """
  Refreshes auth credentials on a failed task's container and resumes
  the session with the original instruction.

  Used when a task fails with a token expiry error — restarts the
  container, pushes fresh auth from the host's auth.json, then creates
  a new resume task.

  **Warning:** This performs blocking I/O (container restart + health polling).
  Call from an async context (e.g., spawned Task), not directly from a
  LiveView handler.
  """
  @spec refresh_auth_and_resume(String.t(), String.t(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def refresh_auth_and_resume(task_id, user_id, opts \\ []) do
    opts = inject_task_runner_starter(opts)
    opts = Keyword.put_new(opts, :resume_fn, &resume_task/3)
    RefreshAuthAndResume.execute(task_id, user_id, opts)
  end

  @doc """
  Returns the current queue state for a user.

  Ensures the QueueManager is started for the user.
  Returns a map with `:running`, `:queued`, `:awaiting_feedback`, and `:concurrency_limit`.
  """
  @spec get_queue_state(String.t()) :: map()
  def get_queue_state(user_id) do
    case QueueManagerSupervisor.ensure_started(user_id) do
      {:ok, _pid} -> QueueManager.get_queue_state(user_id)
      {:error, _reason} -> default_queue_state()
    end
  end

  @doc """
  Returns the concurrency limit for a user.
  """
  @spec get_concurrency_limit(String.t()) :: non_neg_integer()
  def get_concurrency_limit(user_id) do
    case QueueManagerSupervisor.ensure_started(user_id) do
      {:ok, _pid} -> QueueManager.get_concurrency_limit(user_id)
      {:error, _reason} -> SessionsConfig.default_concurrency_limit()
    end
  end

  @doc """
  Sets the concurrency limit for a user.

  May trigger promotion of queued tasks if the new limit allows more concurrency.
  """
  @spec set_concurrency_limit(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def set_concurrency_limit(user_id, limit) do
    with {:ok, _pid} <- QueueManagerSupervisor.ensure_started(user_id) do
      QueueManager.set_concurrency_limit(user_id, limit)
    end
  end

  defp default_queue_state do
    %{
      running: 0,
      queued: [],
      awaiting_feedback: [],
      concurrency_limit: SessionsConfig.default_concurrency_limit()
    }
  end

  defp inject_queue_checker(opts) do
    Keyword.put_new(opts, :queue_checker, &default_queue_checker/1)
  end

  defp default_queue_checker(user_id) do
    case QueueManagerSupervisor.ensure_started(user_id) do
      {:ok, _pid} -> QueueManager.check_concurrency(user_id)
      {:error, _reason} -> :ok
    end
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
