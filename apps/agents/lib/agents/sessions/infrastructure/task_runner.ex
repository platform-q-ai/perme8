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
    events: [],
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

  def handle_info(:wait_for_health, %{health_retries: 0} = state) do
    fail_task(state, "Health check timed out")
    {:stop, :normal, state}
  end

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

  # ---- Event Streaming ----

  def handle_info({:opencode_event, event}, state) do
    new_events = state.events ++ [event]

    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, event}
    )

    # Check for completion events
    case detect_completion(event) do
      :completed ->
        complete_task(state)
        {:stop, :normal, %{state | events: new_events}}

      :error ->
        error_msg = extract_error(event)
        fail_task(state, error_msg || "Unknown error from opencode")
        {:stop, :normal, %{state | events: new_events}}

      :continue ->
        {:noreply, %{state | events: new_events}}
    end
  end

  # ---- Timeout ----

  def handle_info(:timeout, state) do
    fail_task(state, "Task timed out")
    {:stop, :normal, state}
  end

  # ---- Cancellation ----

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

  defp detect_completion(%{"type" => "message.completed"}), do: :completed
  defp detect_completion(%{"type" => "error"}), do: :error
  defp detect_completion(_), do: :continue

  defp extract_error(%{"error" => error}) when is_binary(error), do: error
  defp extract_error(%{"message" => msg}) when is_binary(msg), do: msg
  defp extract_error(_), do: nil
end
