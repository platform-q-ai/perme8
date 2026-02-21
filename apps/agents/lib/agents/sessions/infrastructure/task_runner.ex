defmodule Agents.Sessions.Infrastructure.TaskRunner do
  @moduledoc """
  GenServer managing the full lifecycle of a coding task.

  One TaskRunner per task. Orchestrates:
  1. Starting a Docker container
  2. Waiting for health check
  3. Creating an opencode session
  4. Sending the user's prompt
  5. Streaming events via PubSub
  6. Handling completion, failure, cancellation, and timeout
  7. Cleanup (container stop)

  Events from the opencode SDK SSE stream follow these types:
  - `"session.status"` - status changes (running → idle = completed)
  - `"message.part.updated"` - text/tool output streaming
  - `"permission.asked"` - tool permission requests (auto-approved)
  - `"session.error"` - session-level errors
  - `"server.connected"` - initial connection
  """
  use GenServer

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  require Logger

  defstruct [
    :task_id,
    :container_id,
    :container_port,
    :session_id,
    :instruction,
    :user_id,
    :timeout_ref,
    status: :starting,
    health_retries: 0,
    # Track whether we've seen session go to "running" so we know
    # that a transition to "idle" means completion
    was_running: false,
    # Dependency injection
    container_provider: nil,
    opencode_client: nil,
    task_repo: nil,
    pubsub: nil
  ]

  # ---- Public API ----

  def start_link({task_id, opts}) do
    GenServer.start_link(__MODULE__, {task_id, opts}, name: via_tuple(task_id))
  end

  def via_tuple(task_id) do
    {:via, Registry, {Agents.Sessions.TaskRegistry, task_id}}
  end

  # ---- Callbacks ----

  @impl true
  def init({task_id, opts}) do
    container_provider =
      Keyword.get(
        opts,
        :container_provider,
        Agents.Sessions.Infrastructure.Adapters.DockerAdapter
      )

    opencode_client =
      Keyword.get(
        opts,
        :opencode_client,
        Agents.Sessions.Infrastructure.Clients.OpencodeClient
      )

    task_repo =
      Keyword.get(
        opts,
        :task_repo,
        Agents.Sessions.Infrastructure.Repositories.TaskRepository
      )

    pubsub = Keyword.get(opts, :pubsub, Jarga.PubSub)

    # Load task from DB to get instruction and user_id
    case task_repo.get_task(task_id) do
      nil ->
        Logger.warning("TaskRunner: task #{task_id} not found during init, stopping")
        {:stop, :task_not_found}

      task ->
        state = %__MODULE__{
          task_id: task_id,
          instruction: task.instruction,
          user_id: task.user_id,
          container_provider: container_provider,
          opencode_client: opencode_client,
          task_repo: task_repo,
          pubsub: pubsub,
          health_retries: SessionsConfig.health_check_max_retries()
        }

        # Set task timeout
        timeout_ms = SessionsConfig.task_timeout_ms()
        timeout_ref = Process.send_after(self(), :timeout, timeout_ms)
        state = %{state | timeout_ref: timeout_ref}

        # Start the lifecycle
        send(self(), :start_container)

        {:ok, state}
    end
  end

  # ---- Container Start ----

  @impl true
  def handle_info(:start_container, state) do
    image = SessionsConfig.image()

    case state.container_provider.start(image, []) do
      {:ok, %{container_id: container_id, port: port}} ->
        update_task_status(state, %{
          status: "starting",
          container_id: container_id,
          container_port: port
        })

        broadcast_status(state.task_id, "starting", state.pubsub)

        new_state = %{
          state
          | container_id: container_id,
            container_port: port,
            status: :health_check
        }

        send(self(), :wait_for_health)
        {:noreply, new_state}

      {:error, reason} ->
        fail_task(state, "Container start failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  # ---- Health Check ----

  @impl true
  def handle_info(:wait_for_health, %{health_retries: 0} = state) do
    fail_task(state, "Health check timed out")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:wait_for_health, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.health(base_url) do
      :ok ->
        send(self(), :create_session)
        {:noreply, %{state | status: :creating_session}}

      {:error, _reason} ->
        interval = SessionsConfig.health_check_interval_ms()
        Process.send_after(self(), :wait_for_health, interval)
        {:noreply, %{state | health_retries: state.health_retries - 1}}
    end
  end

  # ---- Session Create & Prompt ----

  @impl true
  def handle_info(:create_session, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.create_session(base_url, []) do
      {:ok, %{"id" => session_id}} ->
        # Subscribe to SSE events
        state.opencode_client.subscribe_events(base_url, self())

        send(self(), :send_prompt)
        {:noreply, %{state | session_id: session_id, status: :prompting}}

      {:error, reason} ->
        fail_task(state, "Session creation failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(:send_prompt, state) do
    base_url = "http://localhost:#{state.container_port}"
    parts = [%{type: "text", text: state.instruction}]

    case state.opencode_client.send_prompt_async(base_url, state.session_id, parts, []) do
      :ok ->
        update_task_status(state, %{
          status: "running",
          started_at: DateTime.utc_now()
        })

        broadcast_status(state.task_id, "running", state.pubsub)
        {:noreply, %{state | status: :running}}

      {:error, reason} ->
        fail_task(state, "Prompt send failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  # ---- Event Streaming (opencode SDK events) ----

  @impl true
  def handle_info({:opencode_event, event}, state) do
    # Broadcast all events to the LiveView via PubSub
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, event}
    )

    # Handle event by type
    case handle_sdk_event(event, state) do
      {:completed, new_state} ->
        complete_task(new_state)
        {:stop, :normal, new_state}

      {:error, error_msg, new_state} ->
        fail_task(new_state, error_msg)
        {:stop, :normal, new_state}

      {:permission, session_id, permission_id, new_state} ->
        # Auto-approve all tool permission requests
        base_url = "http://localhost:#{new_state.container_port}"

        new_state.opencode_client.reply_permission(
          base_url,
          session_id,
          permission_id,
          "always",
          []
        )

        {:noreply, new_state}

      {:continue, new_state} ->
        {:noreply, new_state}
    end
  end

  # ---- SSE Error ----

  @impl true
  def handle_info({:opencode_error, reason}, state) do
    fail_task(state, "SSE connection failed: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  # ---- SSE Process Down ----

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) when reason != :normal do
    fail_task(state, "SSE process crashed: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  # ---- Timeout ----

  @impl true
  def handle_info(:timeout, state) do
    fail_task(state, "Task timed out")
    {:stop, :normal, state}
  end

  # ---- Cancellation ----

  @impl true
  def handle_info(:cancel, state) do
    if state.session_id && state.container_port do
      base_url = "http://localhost:#{state.container_port}"
      state.opencode_client.abort_session(base_url, state.session_id)
    end

    update_task_status(state, %{
      status: "cancelled",
      completed_at: DateTime.utc_now()
    })

    broadcast_status(state.task_id, "cancelled", state.pubsub)
    cleanup_container(state)
    {:stop, :normal, state}
  end

  # ---- Terminate (defensive cleanup) ----

  @impl true
  def terminate(_reason, state) do
    cleanup_container(state)
    :ok
  end

  # ---- Private: SDK Event Handling ----

  # Session status changes: running → idle means the task completed
  defp handle_sdk_event(%{"type" => "session.status", "properties" => props}, state) do
    status_type = get_in(props, ["status", "type"]) || props["status"]

    case status_type do
      status when status in ["running", "busy"] ->
        {:continue, %{state | was_running: true}}

      "idle" when state.was_running ->
        # Session went from running → idle, task is done
        {:completed, state}

      "idle" ->
        {:continue, state}

      "error" ->
        error = get_in(props, ["error"]) || "Session entered error state"
        {:error, error, state}

      _ ->
        {:continue, state}
    end
  end

  # Session error events
  defp handle_sdk_event(%{"type" => "session.error", "properties" => props}, state) do
    error = props["error"] || "Unknown session error"
    {:error, error, state}
  end

  # Permission requests - auto-approve
  defp handle_sdk_event(%{"type" => "permission.asked", "properties" => props}, state) do
    permission_id = props["id"]
    session_id = props["sessionID"]

    if permission_id && session_id do
      {:permission, session_id, permission_id, state}
    else
      {:continue, state}
    end
  end

  # All other events (message.part.updated, server.connected, etc.)
  # are broadcast via PubSub but don't change runner state
  defp handle_sdk_event(_event, state) do
    {:continue, state}
  end

  # ---- Private helpers ----

  defp update_task_status(state, attrs) do
    case state.task_repo.get_task(state.task_id) do
      %TaskSchema{} = task ->
        state.task_repo.update_task_status(task, attrs)

      nil ->
        Logger.warning("TaskRunner: task #{state.task_id} not found in DB")
    end
  end

  defp fail_task(state, error) do
    update_task_status(state, %{
      status: "failed",
      error: error,
      completed_at: DateTime.utc_now()
    })

    broadcast_status(state.task_id, "failed", state.pubsub)
    cleanup_container(state)
  end

  defp complete_task(state) do
    update_task_status(state, %{
      status: "completed",
      completed_at: DateTime.utc_now()
    })

    broadcast_status(state.task_id, "completed", state.pubsub)
    cleanup_container(state)
  end

  defp cleanup_container(%{container_id: nil}), do: :ok

  defp cleanup_container(state) do
    state.container_provider.stop(state.container_id)
  rescue
    _ -> :ok
  end

  defp broadcast_status(task_id, status, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_status_changed, task_id, status}
    )
  end
end
