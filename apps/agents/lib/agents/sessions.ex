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
  alias Agents.Sessions.Infrastructure.Repositories.ProjectTicketRepository
  alias Agents.Sessions.Infrastructure.Repositories.TaskRepository
  alias Agents.Sessions.Infrastructure.TicketSyncServer
  alias Agents.Repo
  alias Agents.Sessions.Infrastructure.TaskRunnerSupervisor
  alias Ecto.Adapters.SQL

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
    opts = inject_concurrency_lock(opts)

    case CreateTask.execute(attrs, opts) do
      {:ok, %{status: "queued", id: task_id} = task} ->
        user_id = attrs[:user_id] || attrs["user_id"]
        _ = notify_task_queued(user_id, task_id)
        {:ok, task}

      other ->
        other
    end
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

    opts = inject_queue_checker(opts)
    opts = inject_concurrency_lock(opts)

    case ResumeTask.execute(task_id, attrs, opts) do
      {:ok, %{status: "queued", id: queued_task_id} = task} ->
        user_id = attrs[:user_id] || attrs["user_id"]
        _ = notify_task_queued(user_id, queued_task_id)
        {:ok, task}

      other ->
        other
    end
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
  Lists persisted project tickets enriched with per-user session state.

  Tickets are loaded from the agents DB, then each ticket is matched against
  the user's recent tasks by issue number reference in instruction text
  (for example: "#306" or "ticket 306").
  """
  @spec list_project_tickets(String.t(), keyword()) :: [map()]
  def list_project_tickets(user_id, opts \\ []) do
    tasks = Keyword.get_lazy(opts, :tasks, fn -> list_tasks(user_id, opts) end)

    tickets =
      Keyword.get_lazy(opts, :tickets, fn ->
        ProjectTicketRepository.list_by_statuses(SessionsConfig.github_ticket_statuses())
      end)

    task_by_ticket_number =
      tasks
      |> Enum.reduce(%{}, fn task, acc ->
        case extract_ticket_number(task.instruction) do
          nil -> acc
          number -> Map.put_new(acc, number, task)
        end
      end)

    Enum.map(tickets, fn ticket ->
      task = Map.get(task_by_ticket_number, ticket.number)

      Map.merge(ticket, %{
        associated_task_id: task && task.id,
        associated_container_id: task && task.container_id,
        session_state: task_status_to_session_state(task && task.status),
        task_status: task && task.status,
        task_error: task && task.error
      })
    end)
  end

  @doc "Reorders a synced project ticket and optionally moves it to a new board status."
  @spec reorder_project_ticket(integer(), String.t() | nil, [integer()]) :: :ok | {:error, term()}
  def reorder_project_ticket(ticket_number, target_status, ordered_ticket_numbers) do
    TicketSyncServer.reorder_ticket(ticket_number, target_status, ordered_ticket_numbers)
  end

  @doc """
  Updates a persisted ticket locally and schedules reconciliation to GitHub.
  """
  @spec update_project_ticket(integer(), map()) :: {:ok, struct()} | {:error, term()}
  def update_project_ticket(number, attrs) when is_integer(number) and is_map(attrs) do
    ProjectTicketRepository.update_local_ticket(number, attrs)
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
  @spec answer_question(String.t(), String.t(), [[String.t()]], String.t() | nil) ::
          :ok | {:error, term()}
  def answer_question(task_id, request_id, answers, message \\ nil) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.call(pid, {:answer_question, request_id, answers, message})
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
  @spec send_message(String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def send_message(task_id, message, opts \\ []) do
    case Registry.lookup(Agents.Sessions.TaskRegistry, task_id) do
      [{pid, _}] -> GenServer.call(pid, {:send_message, message, opts})
      [] -> restart_runner_and_send(task_id, message, opts)
    end
  end

  defp restart_runner_and_send(task_id, message, opts) do
    task_repo = Keyword.get(opts, :task_repo, TaskRepository)
    opts = inject_task_runner_starter(opts)
    starter = Keyword.fetch!(opts, :task_runner_starter)
    task = task_repo.get_task(task_id)

    restart_runner_for_task(task, task_id, message, task_repo, starter)
  end

  defp restart_runner_for_task(%{status: "cancelled"}, _task_id, _message, _task_repo, _starter) do
    {:error, :task_not_running}
  end

  defp restart_runner_for_task(
         %{container_id: cid, session_id: sid, instruction: instruction},
         task_id,
         message,
         _task_repo,
         starter
       )
       when is_binary(cid) and cid != "" and is_binary(sid) and sid != "" do
    start_resumed_runner(starter, task_id, instruction, message, cid, sid)
  end

  defp restart_runner_for_task(
         %{status: status} = task,
         _task_id,
         _message,
         task_repo,
         _starter
       )
       when status in ["pending", "starting", "running", "awaiting_feedback"] do
    _ = maybe_mark_runner_linkage_missing(task_repo, task)
    {:error, :task_not_running}
  end

  defp restart_runner_for_task(_task, _task_id, _message, _task_repo, _starter) do
    {:error, :task_not_running}
  end

  defp start_resumed_runner(starter, task_id, instruction, message, cid, sid) do
    case starter.(task_id,
           resume: true,
           instruction: instruction,
           prompt_instruction: message,
           container_id: cid,
           session_id: sid
         ) do
      {:ok, _pid} -> :ok
      _ -> {:error, :task_not_running}
    end
  end

  defp maybe_mark_runner_linkage_missing(task_repo, task) do
    if function_exported?(task_repo, :update_task_status, 2) do
      task_repo.update_task_status(task, %{status: "failed", error: "Runner linkage missing"})
    end
  rescue
    _ -> :ok
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
  Returns a map with `:running`, `:queued`, `:awaiting_feedback`, `:concurrency_limit`, and
  `:warm_cache_limit`.
  """
  @spec get_queue_state(String.t()) :: map()
  def get_queue_state(user_id) do
    case ensure_queue_manager_started(user_id) do
      {:ok, _pid} -> QueueManager.get_queue_state(user_id)
      {:error, _reason} -> default_queue_state()
    end
  end

  @doc """
  Returns the concurrency limit for a user.
  """
  @spec get_concurrency_limit(String.t()) :: non_neg_integer()
  def get_concurrency_limit(user_id) do
    case ensure_queue_manager_started(user_id) do
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
    with {:ok, _pid} <- ensure_queue_manager_started(user_id) do
      QueueManager.set_concurrency_limit(user_id, limit)
    end
  end

  @doc """
  Returns how many queued cold sessions will be prewarmed.
  """
  @spec get_warm_cache_limit(String.t()) :: non_neg_integer()
  def get_warm_cache_limit(user_id) do
    case ensure_queue_manager_started(user_id) do
      {:ok, _pid} -> QueueManager.get_warm_cache_limit(user_id)
      {:error, _reason} -> 2
    end
  end

  @doc """
  Sets how many queued cold sessions should be prewarmed.
  """
  @spec set_warm_cache_limit(String.t(), non_neg_integer()) :: :ok | {:error, term()}
  def set_warm_cache_limit(user_id, limit) do
    with {:ok, _pid} <- ensure_queue_manager_started(user_id) do
      QueueManager.set_warm_cache_limit(user_id, limit)
    end
  end

  @doc """
  Notifies queue management when a task reaches a terminal status.

  Used by TaskRunner terminal paths to trigger promotion of queued tasks
  when a concurrency slot opens up.
  """
  @spec notify_task_terminal_status(
          String.t(),
          String.t(),
          :completed | :failed | :cancelled,
          keyword()
        ) ::
          :ok
  def notify_task_terminal_status(user_id, task_id, status, opts \\ [])

  def notify_task_terminal_status(user_id, task_id, status, opts)
      when status in [:completed, :failed, :cancelled] do
    queue_manager_supervisor =
      Keyword.get(opts, :queue_manager_supervisor, QueueManagerSupervisor)

    queue_manager = Keyword.get(opts, :queue_manager, QueueManager)

    ensure_opts = Keyword.get(opts, :queue_manager_opts, default_queue_manager_opts())

    with {:ok, _pid} <- safe_ensure_queue_manager(queue_manager_supervisor, user_id, ensure_opts) do
      _ = safe_notify_terminal(queue_manager, user_id, task_id, status)
    end

    :ok
  end

  @doc """
  Notifies queue management when a new task is queued.

  Triggers prewarming for top queued sessions so they are faster to start
  when promoted into an available concurrency slot.
  """
  @spec notify_task_queued(String.t(), String.t(), keyword()) :: :ok
  def notify_task_queued(user_id, task_id, opts \\ []) do
    queue_manager_supervisor =
      Keyword.get(opts, :queue_manager_supervisor, QueueManagerSupervisor)

    queue_manager = Keyword.get(opts, :queue_manager, QueueManager)
    ensure_opts = Keyword.get(opts, :queue_manager_opts, default_queue_manager_opts())

    with {:ok, _pid} <- safe_ensure_queue_manager(queue_manager_supervisor, user_id, ensure_opts) do
      _ = safe_notify_task_queued(queue_manager, user_id, task_id)
    end

    :ok
  end

  defp default_queue_state do
    %{
      running: 0,
      queued: [],
      awaiting_feedback: [],
      concurrency_limit: SessionsConfig.default_concurrency_limit(),
      warm_cache_limit: 2
    }
  end

  defp safe_ensure_queue_manager(queue_manager_supervisor, user_id, ensure_opts) do
    if function_exported?(queue_manager_supervisor, :ensure_started, 2) do
      queue_manager_supervisor.ensure_started(user_id, ensure_opts)
    else
      queue_manager_supervisor.ensure_started(user_id)
    end
  rescue
    _ -> {:error, :queue_manager_unavailable}
  catch
    :exit, _ -> {:error, :queue_manager_unavailable}
  end

  defp safe_notify_terminal(queue_manager, user_id, task_id, :completed) do
    queue_manager.notify_task_completed(user_id, task_id)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_notify_terminal(queue_manager, user_id, task_id, :failed) do
    queue_manager.notify_task_failed(user_id, task_id)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_notify_terminal(queue_manager, user_id, task_id, :cancelled) do
    queue_manager.notify_task_cancelled(user_id, task_id)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp safe_notify_task_queued(queue_manager, user_id, task_id) do
    queue_manager.notify_task_queued(user_id, task_id)
  rescue
    _ -> :ok
  catch
    :exit, _ -> :ok
  end

  defp inject_queue_checker(opts) do
    Keyword.put_new(opts, :queue_checker, &default_queue_checker/1)
  end

  defp inject_concurrency_lock(opts) do
    Keyword.put_new(opts, :concurrency_lock, &with_create_task_lock/2)
  end

  defp with_create_task_lock(user_id, fun) do
    lock_key = :erlang.phash2("sessions:create_task:#{user_id}", 2_147_483_647)

    Repo.transaction(fn ->
      SQL.query!(Repo, "SELECT pg_advisory_xact_lock($1)", [lock_key])

      case fun.() do
        {:error, reason} -> Repo.rollback(reason)
        other -> other
      end
    end)
    |> case do
      {:ok, result} -> result
      {:error, {:error, reason}} -> {:error, reason}
      {:error, error} -> error
    end
  end

  defp default_queue_checker(user_id) do
    case ensure_queue_manager_started(user_id) do
      {:ok, _pid} -> QueueManager.check_concurrency(user_id)
      {:error, _reason} -> :at_limit
    end
  end

  defp ensure_queue_manager_started(user_id) do
    safe_ensure_queue_manager(QueueManagerSupervisor, user_id, default_queue_manager_opts())
  end

  defp default_queue_manager_opts do
    [
      task_runner_starter: fn task_id, runner_opts ->
        runner_opts =
          Keyword.put_new(
            runner_opts,
            :queue_terminal_notifier,
            &notify_task_terminal_status/3
          )

        TaskRunnerSupervisor.start_child(task_id, runner_opts)
      end
    ]
  end

  # Wire the real TaskRunnerSupervisor starter
  defp inject_task_runner_starter(opts) do
    if Keyword.has_key?(opts, :task_runner_starter) do
      opts
    else
      Keyword.put(opts, :task_runner_starter, fn task_id, runner_opts ->
        runner_opts =
          Keyword.put_new(
            runner_opts,
            :queue_terminal_notifier,
            &notify_task_terminal_status/3
          )

        TaskRunnerSupervisor.start_child(task_id, runner_opts)
      end)
    end
  end

  @doc false
  @spec extract_ticket_number(term()) :: integer() | nil
  def extract_ticket_number(instruction) when is_binary(instruction) do
    case Regex.run(~r/(?:^|\s)(?:#|ticket\s+)(\d+)\b/i, instruction) do
      [_, value] -> String.to_integer(value)
      _ -> nil
    end
  end

  def extract_ticket_number(_), do: nil

  defp task_status_to_session_state(nil), do: "idle"

  defp task_status_to_session_state(status)
       when status in ["pending", "starting", "running", "queued", "awaiting_feedback"],
       do: "running"

  defp task_status_to_session_state("completed"), do: "completed"
  defp task_status_to_session_state(_), do: "paused"
end
