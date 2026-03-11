defmodule Agents.Sessions.Infrastructure.TaskRunner do
  @moduledoc """
  GenServer managing the full lifecycle of a coding task.

  One TaskRunner per task. Orchestrates:
  1. Starting a Docker container
  2. Waiting for health check
  3. Creating an opencode session
  4. Sending the user's prompt
  5. Streaming events via PubSub
  6. Handling completion, failure, and cancellation
  7. Cleanup (container stop)

  Events from the opencode SDK SSE stream follow these types:
  - `"session.status"` - status changes (running → idle = completed)
  - `"message.part.updated"` - text/tool output streaming
  - `"todo.updated"` - todo/step progress updates
  - `"permission.asked"` - tool permission requests (auto-approved)
  - `"question.asked"` - questions requiring user input
  - `"session.error"` - session-level errors
  - `"server.connected"` - initial connection
  """
  use GenServer, restart: :temporary

  alias Agents.Sessions.Application.SessionsConfig
  alias Agents.Sessions.Application.Services.AuthRefresher
  alias Agents.Sessions.Domain.Entities.Session
  alias Agents.Sessions.Domain.Entities.TodoList
  alias Agents.Sessions.Domain.Events.{TaskCompleted, TaskFailed, TaskCancelled}
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Sessions.Infrastructure.SdkEventHandler
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema

  require Logger

  defstruct [
    :task_id,
    :container_id,
    :container_port,
    :session_id,
    :instruction,
    :image,
    :user_id,
    :flush_ref,
    :question_timeout_ref,
    :pending_question_request_id,
    :pending_question_data,
    :sse_pid,
    :auth_refresher,
    :fresh_warm_container,
    :session,
    status: :starting,
    health_retries: 0,
    sse_reconnecting: false,
    # Track whether we've seen session go to "running" so we know
    # that a transition to "idle" means completion
    was_running: false,
    # Latest assistant text output for DB caching (opencode sends full text on each update)
    output_text: "",
    # Structured output parts for rich DB caching — keyed by part ID
    output_parts: [],
    # Track last flushed version to avoid redundant DB writes
    last_flushed_count: 0,
    todo_items: [],
    prior_resume_items: [],
    todo_version: 0,
    last_flushed_todo_version: 0,
    # User message IDs — skip their parts from output cache (shown separately in UI)
    user_message_ids: MapSet.new(),
    # Subtask message IDs — skip user message tracking for subagent invocations
    subtask_message_ids: MapSet.new(),
    # Child session IDs mapped to subtask part IDs for status updates
    child_session_ids: %{},
    # Dependency injection
    container_provider: nil,
    opencode_client: nil,
    task_repo: nil,
    pubsub: nil,
    event_bus: nil,
    queue_terminal_notifier: nil
  ]

  # ---- Public API ----

  @spec start_link({String.t(), keyword()}) :: GenServer.on_start()
  def start_link({task_id, opts}) do
    GenServer.start_link(__MODULE__, {task_id, opts}, name: via_tuple(task_id))
  end

  @spec via_tuple(String.t()) :: {:via, module(), {module(), String.t()}}
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

    pubsub = Keyword.get(opts, :pubsub, SessionsConfig.pubsub())
    event_bus = Keyword.get(opts, :event_bus, Perme8.Events.EventBus)

    queue_terminal_notifier =
      Keyword.get(opts, :queue_terminal_notifier, fn _, _, _ -> :ok end)

    # Resume context — if resuming, we already have container_id and session_id
    resume? = Keyword.get(opts, :resume, false)
    resume_container_id = Keyword.get(opts, :container_id)
    resume_session_id = Keyword.get(opts, :session_id)
    prewarmed_container_id = Keyword.get(opts, :prewarmed_container_id)
    fresh_warm_container = Keyword.get(opts, :fresh_warm_container, false)
    prompt_instruction = Keyword.get(opts, :prompt_instruction)
    auth_refresher = Keyword.get(opts, :auth_refresher, AuthRefresher)

    # Load task from DB to get instruction and user_id
    case task_repo.get_task(task_id) do
      nil ->
        Logger.warning("TaskRunner: task #{task_id} not found during init, stopping")
        {:stop, :task_not_found}

      task ->
        state = %__MODULE__{
          task_id: task_id,
          instruction:
            if(resume? and is_binary(prompt_instruction),
              do: prompt_instruction,
              else: task.instruction
            ),
          image: task.image || SessionsConfig.image(),
          user_id: task.user_id,
          container_provider: container_provider,
          opencode_client: opencode_client,
          task_repo: task_repo,
          pubsub: pubsub,
          event_bus: event_bus,
          auth_refresher: auth_refresher,
          fresh_warm_container: fresh_warm_container,
          queue_terminal_notifier: queue_terminal_notifier,
          health_retries: SessionsConfig.health_check_max_retries()
        }

        session =
          Session.new(%{
            task_id: task_id,
            user_id: task.user_id,
            lifecycle_state: :starting
          })

        state = %{state | session: session}

        state =
          initialize_lifecycle(
            state,
            task,
            resume?,
            prompt_instruction,
            resume_container_id,
            resume_session_id,
            prewarmed_container_id
          )

        {:ok, state}
    end
  end

  # ---- Question handling (called by LiveView via GenServer.call) ----

  @impl true
  def handle_call({:answer_question, request_id, answers, message}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.reply_question(base_url, request_id, answers, []) do
      :ok ->
        state = cache_answer_message(state, request_id, message, answers)
        broadcast_question_replied(state)
        {:reply, :ok, clear_pending_question(state)}

      {:error, _} = error ->
        {:reply, error, state}
    end
  end

  def handle_call({:answer_question, request_id, answers}, from, state) do
    handle_call({:answer_question, request_id, answers, nil}, from, state)
  end

  @impl true
  def handle_call({:reject_question, request_id}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.reject_question(base_url, request_id, []) do
      :ok -> {:reply, :ok, mark_question_rejected(state)}
      {:error, _} = error -> {:reply, error, state}
    end
  end

  @impl true
  def handle_call({:send_message, message, opts}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"
    parts = [%{"type" => "text", "text" => message}]

    command_payload =
      %{
        "correlation_key" => Keyword.get(opts, :correlation_key),
        "command_type" => Keyword.get(opts, :command_type),
        "sent_at" => Keyword.get(opts, :sent_at)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    result = state.opencode_client.send_prompt_async(base_url, state.session_id, parts, [])

    state =
      if result == :ok do
        cache_queued_user_message(state, message, command_payload)
      else
        state
      end

    {:reply, result, state}
  end

  def handle_call({:send_message, message}, from, state) do
    handle_call({:send_message, message, []}, from, state)
  end

  # ---- Container Start ----

  @impl true
  def handle_info(:start_container, state) do
    image = state.image || SessionsConfig.image()

    case state.container_provider.start(image, []) do
      {:ok, %{container_id: container_id, port: port}} ->
        from_task = state.task_repo.get_task(state.task_id)

        update_task_status(state, %{
          status: "starting",
          container_id: container_id,
          container_port: port,
          completed_at: nil,
          error: nil
        })

        broadcast_status_with_lifecycle(
          state,
          "starting",
          %{
            status: "starting",
            container_id: container_id,
            container_port: port
          },
          from_task
        )

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

  # ---- Container Restart (resume path) ----

  @impl true
  def handle_info(:restart_container, state) do
    case state.container_provider.restart(state.container_id) do
      {:ok, %{port: port}} ->
        from_task = state.task_repo.get_task(state.task_id)

        update_task_status(state, %{
          status: "starting",
          container_port: port,
          completed_at: nil,
          error: nil
        })

        broadcast_status_with_lifecycle(
          state,
          "starting",
          %{
            status: "starting",
            container_port: port
          },
          from_task
        )

        new_state = %{state | container_port: port, status: :health_check}
        send(self(), :wait_for_health_resume)
        {:noreply, new_state}

      {:error, reason} ->
        fail_task(state, "Container restart failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  @impl true
  def handle_info(:restart_prewarmed_container, state) do
    case state.container_provider.restart(state.container_id) do
      {:ok, %{port: port}} ->
        from_task = state.task_repo.get_task(state.task_id)

        update_task_status(state, %{
          status: "starting",
          container_port: port,
          completed_at: nil,
          error: nil
        })

        broadcast_status_with_lifecycle(
          state,
          "starting",
          %{
            status: "starting",
            container_port: port
          },
          from_task
        )

        new_state = %{state | container_port: port, status: :health_check}
        send(self(), :wait_for_health_fresh)
        {:noreply, new_state}

      {:error, reason} ->
        fail_task(state, "Container restart failed: #{inspect(reason)}")
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
    continue_after_health(state, :wait_for_health, :create_session, :creating_session)
  end

  # ---- Resume Health Check (skips session creation) ----

  @impl true
  def handle_info(:wait_for_health_resume, %{health_retries: 0} = state) do
    fail_task(state, "Health check timed out on resume")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:wait_for_health_resume, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.health(base_url) do
      :ok ->
        # Resume path: session already exists, just subscribe and send prompt
        case subscribe_to_events(state) do
          {:ok, state} ->
            send(self(), :send_prompt)
            {:noreply, %{state | status: :prompting}}

          {:error, reason} ->
            fail_task(state, "SSE subscription failed on resume: #{inspect(reason)}")
            {:stop, :normal, state}
        end

      {:error, _reason} ->
        interval = SessionsConfig.health_check_interval_ms()
        Process.send_after(self(), :wait_for_health_resume, interval)
        {:noreply, %{state | health_retries: state.health_retries - 1}}
    end
  end

  @impl true
  def handle_info(:wait_for_health_fresh, %{health_retries: 0} = state) do
    fail_task(state, "Health check timed out on fresh warm container")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(:wait_for_health_fresh, state) do
    continue_after_health(
      state,
      :wait_for_health_fresh,
      :prepare_fresh_start,
      :preparing_fresh_start
    )
  end

  @impl true
  def handle_info(:prepare_fresh_start, %{fresh_warm_container: false} = state) do
    send(self(), :create_session)
    {:noreply, %{state | status: :creating_session}}
  end

  @impl true
  def handle_info(:prepare_fresh_start, state) do
    base_url = "http://localhost:#{state.container_port}"

    with :ok <- state.container_provider.prepare_fresh_start(state.container_id),
         {:ok, _providers} <- state.auth_refresher.refresh_auth(base_url, state.opencode_client) do
      send(self(), :create_session)
      {:noreply, %{state | status: :creating_session}}
    else
      {:error, reason} ->
        fail_task(
          state,
          "Fresh warm start preparation failed: #{sanitize_fresh_start_reason(reason)}"
        )

        {:stop, :normal, state}
    end
  end

  # ---- Session Create & Prompt ----

  @impl true
  def handle_info(:create_session, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.create_session(base_url, []) do
      {:ok, %{"id" => session_id}} ->
        state = %{state | session_id: session_id}

        # Persist session_id to DB for resume and message retrieval
        update_task_status(state, %{session_id: session_id})

        # Broadcast session_id so LiveView can see it without a page refresh
        broadcast_session_id_set(state.task_id, session_id, state.pubsub)

        # Subscribe to SSE events
        case subscribe_to_events(state) do
          {:ok, state} ->
            send(self(), :send_prompt)
            {:noreply, %{state | status: :prompting}}

          {:error, reason} ->
            fail_task(state, "SSE subscription failed: #{inspect(reason)}")
            {:stop, :normal, state}
        end

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
        from_task = state.task_repo.get_task(state.task_id)

        update_task_status(state, %{
          status: "running",
          started_at: DateTime.utc_now(),
          completed_at: nil,
          error: nil
        })

        broadcast_status_with_lifecycle(state, "running", %{status: "running"}, from_task)
        broadcast_container_stats(state)

        flush_ref = schedule_output_flush()

        {:noreply, %{state | status: :running, flush_ref: flush_ref}}

      {:error, reason} ->
        fail_task(state, "Prompt send failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  # ---- Event Streaming (opencode SDK events) ----

  @impl true
  def handle_info({:opencode_event, event}, state) do
    event_session_id = extract_event_session_id(event)

    cond do
      is_nil(event_session_id) or event_session_id == state.session_id ->
        process_parent_session_event(event, state)

      Map.has_key?(state.child_session_ids, event_session_id) ->
        process_child_session_event(event, event_session_id, state)

      true ->
        # Any non-parent session on this container's SSE stream must be a
        # child. Register speculatively (with nil subtask_part_id) so
        # subsequent events route through process_child_session_event/3.
        Logger.debug(
          "TaskRunner: registering unknown session #{event_session_id} as child (pre-subtask-part race)"
        )

        child_session_ids = Map.put_new(state.child_session_ids, event_session_id, nil)
        state = %{state | child_session_ids: child_session_ids}

        # If this is a subtask part event, track the subtask message ID and
        # cache the part. These are semantically parent-session operations
        # (the subtask part appears in the parent's message stream) but the
        # event carries the child's session ID, so it lands here.
        state = track_subtask_message_id(event, state)
        state = cache_subtask_part(event, state)

        process_child_session_event(event, event_session_id, state)
    end
  end

  # ---- Periodic output flush ----

  @impl true
  def handle_info(:flush_output, state) do
    current_count = length(state.output_parts)

    state =
      if current_count > state.last_flushed_count or
           state.todo_version > state.last_flushed_todo_version do
        flush_output_to_db(state)

        %{
          state
          | last_flushed_count: current_count,
            last_flushed_todo_version: state.todo_version
        }
      else
        state
      end

    # Push container stats to subscribers (event-driven, replaces LiveView polling)
    broadcast_container_stats(state)

    # Schedule the next flush if we're still running
    flush_ref = schedule_output_flush()
    {:noreply, %{state | flush_ref: flush_ref}}
  end

  # ---- Question Timeout ----

  @impl true
  def handle_info(:question_timeout, state) do
    case state.pending_question_request_id do
      nil ->
        {:noreply, state}

      request_id ->
        Logger.info(
          "TaskRunner: auto-rejecting unanswered question #{request_id} for task #{state.task_id}"
        )

        base_url = "http://localhost:#{state.container_port}"

        case state.opencode_client.reject_question(base_url, request_id, []) do
          :ok ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "TaskRunner: auto-reject failed for #{request_id} on task #{state.task_id}: #{inspect(reason)}"
            )
        end

        state = mark_question_rejected(state)
        broadcast_question_rejected(state)
        {:noreply, state}
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
  def handle_info({:DOWN, _ref, :process, pid, reason}, state) when reason != :normal do
    if current_sse_process?(state, pid) do
      fail_task(state, "SSE process crashed: #{inspect(reason)}")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, :normal}, state) do
    if should_reconnect_sse?(state, pid) do
      send(self(), :reconnect_sse)
      {:noreply, %{state | sse_pid: nil, sse_reconnecting: true}}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info(:reconnect_sse, state) do
    case subscribe_to_events(state) do
      {:ok, state} ->
        {:noreply, state}

      {:error, reason} ->
        fail_task(state, "SSE reconnection failed: #{inspect(reason)}")
        {:stop, :normal, state}
    end
  end

  # ---- Cancellation ----

  @impl true
  def handle_info(:cancel, state) do
    cancel_flush_timer(state)
    cancel_question_timeout(state)
    from_task = state.task_repo.get_task(state.task_id)

    if state.session_id && state.container_port do
      base_url = "http://localhost:#{state.container_port}"
      state.opencode_client.abort_session(base_url, state.session_id)
    end

    update_task_status(state, %{
      status: "cancelled",
      completed_at: DateTime.utc_now(),
      pending_question: nil
    })

    broadcast_status_with_lifecycle(state, "cancelled", %{status: "cancelled"}, from_task)

    state.event_bus.emit(
      TaskCancelled.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id,
        target_user_id: state.user_id,
        instruction: state.instruction
      })
    )

    notify_queue_terminal(state, :cancelled)

    {:stop, :normal, state}
  end

  # ---- Terminate (single cleanup point) ----
  # Container cleanup is done exclusively here to avoid double-stop.
  # All terminal paths use {:stop, :normal, state} which guarantees
  # terminate/2 is called by OTP.

  @impl true
  def terminate(_reason, state) do
    cleanup_container(state)
    :ok
  end

  # ---- Private: SDK event dispatch ----

  defp handle_sdk_result(event, state) do
    case handle_sdk_event(event, state) do
      {:completed, new_state} ->
        cancel_question_timeout(new_state)
        complete_task(new_state)
        {:stop, :normal, new_state}

      {:error, error_msg, new_state} ->
        cancel_question_timeout(new_state)
        fail_task(new_state, error_msg)
        {:stop, :normal, new_state}

      {:permission, session_id, permission_id, tool_name, new_state} ->
        Logger.info(
          "TaskRunner: auto-approving tool '#{tool_name}' for task #{new_state.task_id}"
        )

        base_url = "http://localhost:#{new_state.container_port}"

        new_state.opencode_client.reply_permission(
          base_url,
          session_id,
          permission_id,
          "always",
          []
        )

        {:noreply, new_state}

      {:question, new_state} ->
        {:noreply, new_state}

      {:continue, new_state} ->
        {:noreply, new_state}
    end
  end

  # ---- Private: Session event isolation ----
  #
  # The opencode SDK's global SSE stream (GET /event) emits events from ALL
  # sessions (parent + children) on a single stream. These functions route
  # events based on their session ID:
  #
  #   - Parent session events → full processing (output cache, status transitions)
  #   - Known child session events → broadcast only (for LiveView subtask cards)
  #   - Unknown session events → speculatively register as child and route
  #     through child processing. Any non-parent session on this container's
  #     stream must be a child; child events often arrive before the parent's
  #     subtask part event that formally registers them.
  #
  # Child session IDs are discovered via subtask part events, which include a
  # sessionID field. The `child_session_ids` map tracks child_session_id →
  # subtask_part_id for marking subtask cards as done when children complete.
  # Speculatively registered children use `nil` as the subtask_part_id until
  # the subtask part event arrives and overwrites it with the real value.

  defp process_parent_session_event(event, state) do
    broadcast_event(event, state)

    # Track subtask message IDs so we can suppress their user messages
    state = track_subtask_message_id(event, state)

    # Track user message IDs so we can filter their parts from output cache
    state = track_user_message_id(event, state)

    # Update Session entity via SdkEventHandler (domain events emitted here)
    state = update_session_from_sdk_event(state, event)

    # Route parts to appropriate caching: subtask -> user -> SDK dispatch
    cond do
      subtask_part?(event) ->
        {:noreply, cache_subtask_part(event, state)}

      user_message_part?(event, state) ->
        {:noreply, cache_user_message_part(event, state)}

      true ->
        handle_sdk_result(event, state)
    end
  end

  defp update_session_from_sdk_event(%{session: nil} = state, _event), do: state

  defp update_session_from_sdk_event(state, event) do
    case SdkEventHandler.handle(state.session, event, event_bus: state.event_bus) do
      {:ok, updated_session} ->
        %{state | session: updated_session}

      {:skip, _reason} ->
        state
    end
  end

  defp process_child_session_event(
         %{"type" => "session.status", "properties" => props} = event,
         child_session_id,
         state
       ) do
    status_type = get_in(props, ["status", "type"]) || props["status"]

    state =
      case status_type do
        "idle" -> mark_subtask_done(state, child_session_id)
        _ -> state
      end

    broadcast_event(event, state)
    {:noreply, state}
  end

  defp process_child_session_event(event, _child_session_id, state) do
    broadcast_event(event, state)
    {:noreply, state}
  end

  defp extract_event_session_id(%{"properties" => props}) when is_map(props) do
    props["sessionID"] || props["session_id"] || get_in(props, ["part", "sessionID"]) ||
      get_in(props, ["part", "session_id"])
  end

  defp extract_event_session_id(_), do: nil

  defp broadcast_event(event, state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, event}
    )
  end

  # Track subtask message IDs for two purposes:
  # 1. Add to `subtask_message_ids` so subsequent user messages from the same
  #    message are suppressed (they are the subagent's prompt, not user input)
  # 2. Register the child session ID in `child_session_ids` so events from
  #    that session are correctly routed to `process_child_session_event/3`
  defp track_subtask_message_id(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "subtask"} = part}
         },
         state
       ) do
    case part["messageID"] || part["messageId"] do
      msg_id when is_binary(msg_id) ->
        subtask_message_ids = MapSet.put(state.subtask_message_ids, msg_id)
        subtask_part_id = "subtask-#{msg_id}"
        child_session_id = part["sessionID"] || part["session_id"]

        child_session_ids =
          if is_binary(child_session_id) and child_session_id != "" do
            Map.put(state.child_session_ids, child_session_id, subtask_part_id)
          else
            state.child_session_ids
          end

        %{state | subtask_message_ids: subtask_message_ids, child_session_ids: child_session_ids}

      _ ->
        state
    end
  end

  defp track_subtask_message_id(_event, state), do: state

  defp subtask_part?(%{
         "type" => "message.part.updated",
         "properties" => %{"part" => %{"type" => "subtask"}}
       }),
       do: true

  defp subtask_part?(_event), do: false

  defp cache_subtask_part(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "subtask"} = part}
         },
         state
       ) do
    # Use messageID/messageId only — part["id"] is the subtask part ID,
    # not the message ID. This must align with EventProcessor's lookup
    # (subtask_message_part?/2) which also only checks messageID/messageId.
    msg_id = part["messageID"] || part["messageId"]
    subtask_id = if is_binary(msg_id), do: "subtask-#{msg_id}", else: nil

    entry = %{
      "type" => "subtask",
      "id" => subtask_id,
      "agent" => part["agent"] || "unknown",
      "description" => part["description"] || "",
      "prompt" => part["prompt"] || "",
      "status" => "running"
    }

    parts = upsert_output_part(state.output_parts, subtask_id, entry)
    %{state | output_parts: parts}
  end

  defp cache_subtask_part(_event, state), do: state

  defp mark_subtask_done(state, child_session_id) do
    case Map.get(state.child_session_ids, child_session_id) do
      nil ->
        state

      subtask_part_id ->
        output_parts =
          Enum.map(state.output_parts, fn
            %{"id" => ^subtask_part_id} = part -> Map.put(part, "status", "done")
            part -> part
          end)

        %{state | output_parts: output_parts}
    end
  end

  # ---- Private: User message filtering ----

  defp track_user_message_id(
         %{
           "type" => "message.updated",
           "properties" => %{"info" => %{"role" => "user"} = info}
         },
         state
       ) do
    case info["id"] || info["messageID"] || info["messageId"] do
      msg_id when is_binary(msg_id) ->
        # Skip tracking for subtask messages — they should not be
        # treated as user messages in the output cache.
        if MapSet.member?(state.subtask_message_ids, msg_id) do
          state
        else
          %{state | user_message_ids: MapSet.put(state.user_message_ids, msg_id)}
        end

      _ ->
        state
    end
  end

  defp track_user_message_id(_event, state), do: state

  # Defense-in-depth: track_user_message_id already skips subtask IDs,
  # so the subtask_message_ids check here is redundant under normal
  # event ordering. Kept as a safety net in case events arrive
  # out of order (e.g., SSE reconnection delivers text before subtask part).
  defp user_message_part?(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"messageID" => msg_id}}
         },
         state
       )
       when is_binary(msg_id) do
    MapSet.member?(state.user_message_ids, msg_id) and
      not MapSet.member?(state.subtask_message_ids, msg_id)
  end

  defp user_message_part?(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"messageId" => msg_id}}
         },
         state
       )
       when is_binary(msg_id) do
    MapSet.member?(state.user_message_ids, msg_id) and
      not MapSet.member?(state.subtask_message_ids, msg_id)
  end

  defp user_message_part?(_event, _state), do: false

  defp cache_user_message_part(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
         },
         state
       )
       when is_binary(text) and text != "" do
    msg_id = part["messageID"] || part["messageId"] || part["id"]
    part_id = if is_binary(msg_id), do: "user-" <> msg_id, else: nil

    entry = %{"type" => "user", "id" => part_id, "text" => text}
    {parts, matched?} = promote_pending_user_part(state.output_parts, text, part_id)
    parts = if matched?, do: parts, else: upsert_output_part(parts, part_id, entry)
    %{state | output_parts: parts}
  end

  defp cache_user_message_part(_event, state), do: state

  defp cache_queued_user_message(state, message, command_payload \\ %{})

  defp cache_queued_user_message(state, message, command_payload) when is_binary(message) do
    text = String.trim(message)

    if text == "" do
      state
    else
      correlation_key = Map.get(command_payload, "correlation_key")

      pending_id =
        if is_binary(correlation_key) and correlation_key != "" do
          "queued-user-#{correlation_key}"
        else
          "queued-user-#{System.unique_integer([:positive])}"
        end

      entry =
        %{"type" => "user", "id" => pending_id, "text" => text, "pending" => true}
        |> maybe_put_payload_field("correlation_key", Map.get(command_payload, "correlation_key"))
        |> maybe_put_payload_field("command_type", Map.get(command_payload, "command_type"))
        |> maybe_put_payload_field("sent_at", Map.get(command_payload, "sent_at"))

      output_parts = upsert_output_part(state.output_parts, pending_id, entry)
      state = %{state | output_parts: output_parts}
      flush_output_to_db(state)
      state
    end
  end

  defp cache_queued_user_message(state, _message, _command_payload), do: state

  defp maybe_put_payload_field(entry, _key, nil), do: entry
  defp maybe_put_payload_field(entry, _key, ""), do: entry
  defp maybe_put_payload_field(entry, key, value), do: Map.put(entry, key, value)

  defp maybe_cache_resume_prompt_message(state, message) when is_binary(message) do
    if String.trim(message) == "" do
      state
    else
      cache_queued_user_message(state, message)
    end
  end

  defp maybe_cache_resume_prompt_message(state, _message), do: state

  defp promote_pending_user_part(parts, text, part_id) do
    case Enum.find_index(parts, fn
           %{"type" => "user", "pending" => true, "text" => pending_text} ->
             String.trim(to_string(pending_text || "")) == String.trim(text)

           _ ->
             false
         end) do
      nil ->
        {parts, false}

      idx ->
        replacement = %{"type" => "user", "id" => part_id, "text" => text}
        {List.replace_at(parts, idx, replacement), true}
    end
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
    tool_name = extract_tool_name(props)

    if permission_id && session_id do
      {:permission, session_id, permission_id, tool_name, state}
    else
      {:continue, state}
    end
  end

  # Question requests with empty/missing questions — auto-reject immediately
  defp handle_sdk_event(
         %{"type" => "question.asked", "properties" => %{"questions" => []} = props},
         state
       ) do
    auto_reject_empty_question(props["id"], state)
  end

  defp handle_sdk_event(
         %{"type" => "question.asked", "properties" => %{"questions" => nil} = props},
         state
       ) do
    auto_reject_empty_question(props["id"], state)
  end

  defp handle_sdk_event(
         %{"type" => "question.asked", "properties" => props},
         state
       )
       when not is_map_key(props, "questions") do
    auto_reject_empty_question(props["id"], state)
  end

  # Question requests — persist to DB, set timeout, broadcast to LiveView
  defp handle_sdk_event(%{"type" => "question.asked", "properties" => props} = _event, state) do
    request_id = props["id"]

    # Persist question to DB so it survives LiveView reconnections
    question_data = %{
      "request_id" => request_id,
      "session_id" => props["sessionID"],
      "questions" => props["questions"],
      "asked_at" => DateTime.to_iso8601(DateTime.utc_now())
    }

    update_task_status(state, %{pending_question: question_data})

    # Cancel any existing question timeout and schedule a new one
    cancel_question_timeout(state)
    timeout_ms = SessionsConfig.question_timeout_ms()
    timeout_ref = Process.send_after(self(), :question_timeout, timeout_ms)

    new_state = %{
      state
      | pending_question_request_id: request_id,
        pending_question_data: question_data,
        question_timeout_ref: timeout_ref
    }

    {:question, new_state}
  end

  # Step progress events — parse and broadcast to LiveView, cache in state
  defp handle_sdk_event(
         %{"type" => "todo.updated", "properties" => props},
         state
       )
       when is_map(props) do
    case parse_todo_event(props) do
      {:ok, todo_items} ->
        merged_items = merge_prior_resume_items(state.prior_resume_items, todo_items)
        broadcast_todo_update(state.task_id, merged_items, state.pubsub)

        {:continue, %{state | todo_items: merged_items, todo_version: state.todo_version + 1}}

      {:error, _reason} ->
        Logger.warning("TaskRunner: malformed todo.updated event for task #{state.task_id}")
        {:continue, state}
    end
  end

  defp handle_sdk_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
         },
         state
       )
       when is_binary(text) and text != "" do
    part_id = part["id"] || "text-default"
    entry = %{"type" => "text", "id" => part_id, "text" => text}
    parts = upsert_output_part(state.output_parts, part_id, entry)
    {:continue, %{state | output_text: text, output_parts: parts}}
  end

  # Reasoning/thinking content — accumulate for DB caching
  defp handle_sdk_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "reasoning", "text" => text} = part}
         },
         state
       )
       when is_binary(text) and text != "" do
    part_id = part["id"] || "reasoning-default"
    entry = %{"type" => "reasoning", "id" => part_id, "text" => text}
    parts = upsert_output_part(state.output_parts, part_id, entry)
    {:continue, %{state | output_parts: parts}}
  end

  # Tool start — record in output_parts (legacy format)
  defp handle_sdk_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "tool-start"} = part}
         },
         state
       ) do
    tool_id = part["id"]
    tool_name = part["name"] || "tool"

    entry = %{
      "type" => "tool",
      "id" => tool_id,
      "name" => tool_name,
      "status" => "running",
      "input" => part["input"] || part["args"],
      "title" => nil,
      "output" => nil,
      "error" => nil
    }

    parts = upsert_output_part(state.output_parts, tool_id, entry)
    {:continue, %{state | output_parts: parts}}
  end

  # SDK-style tool part with state — cache the full detail
  defp handle_sdk_event(
         %{
           "type" => "message.part.updated",
           "properties" => %{
             "part" => %{"type" => "tool", "state" => %{} = tool_state} = part
           }
         },
         state
       ) do
    tool_id = part["id"]
    existing = Enum.find(state.output_parts, fn p -> p["id"] == tool_id end) || %{}
    entry = build_tool_entry(part, tool_state, existing)
    parts = upsert_output_part(state.output_parts, tool_id, entry)
    {:continue, %{state | output_parts: parts}}
  end

  # session.updated — persist session summary (files changed, additions, deletions)
  defp handle_sdk_event(
         %{"type" => "session.updated", "properties" => %{"info" => %{"summary" => summary}}},
         state
       )
       when is_map(summary) do
    if valid_session_summary?(summary) do
      update_task_status(state, %{session_summary: summary})
    else
      Logger.warning(
        "TaskRunner: invalid session summary for task #{state.task_id}: #{inspect(summary)}"
      )
    end

    {:continue, state}
  end

  # All other events (server.connected, tool result, etc.)
  # are broadcast via PubSub but don't change runner state
  defp handle_sdk_event(_event, state) do
    {:continue, state}
  end

  defp build_tool_entry(part, tool_state, existing) do
    Map.merge(existing, %{
      "type" => "tool",
      "id" => part["id"],
      "name" => part["tool"] || part["name"] || "tool",
      "status" => normalize_tool_status(tool_state["status"]),
      "input" => tool_state["input"] || existing["input"],
      "title" => tool_state["title"] || existing["title"],
      "output" => tool_state["output"] || existing["output"],
      "error" => tool_state["error"] || existing["error"]
    })
  end

  defp normalize_tool_status("completed"), do: "done"
  defp normalize_tool_status("error"), do: "error"
  defp normalize_tool_status(_), do: "running"

  # ---- Private helpers ----

  # Extract a printable tool name from permission.asked properties.
  # The "tool" field can be a map (e.g. %{"callID" => ..., "messageID" => ...})
  # so we fall back to the "permission" type or "name" field.
  defp extract_tool_name(%{"tool" => tool}) when is_binary(tool), do: tool
  defp extract_tool_name(%{"permission" => perm}) when is_binary(perm), do: perm
  defp extract_tool_name(%{"name" => name}) when is_binary(name), do: name
  defp extract_tool_name(_), do: "unknown"

  defp subscribe_to_events(state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.subscribe_events(base_url, self()) do
      {:ok, pid} -> {:ok, %{state | sse_pid: pid, sse_reconnecting: false}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp continue_after_health(state, retry_event, next_event, next_status) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.health(base_url) do
      :ok ->
        send(self(), next_event)
        {:noreply, %{state | status: next_status}}

      {:error, _reason} ->
        interval = SessionsConfig.health_check_interval_ms()
        Process.send_after(self(), retry_event, interval)
        {:noreply, %{state | health_retries: state.health_retries - 1}}
    end
  end

  defp initialize_lifecycle(
         state,
         task,
         true,
         prompt_instruction,
         resume_container_id,
         resume_session_id,
         _prewarmed_container_id
       ) do
    existing_parts = restore_output_parts(task.output)
    existing_todos = restore_todo_items(task.todo_items)

    state = %{
      state
      | container_id: resume_container_id,
        session_id: resume_session_id,
        output_parts: existing_parts,
        last_flushed_count: length(existing_parts),
        todo_items: existing_todos,
        prior_resume_items: existing_todos,
        todo_version: if(existing_todos == [], do: 0, else: 1),
        last_flushed_todo_version: if(existing_todos == [], do: 0, else: 1)
    }

    state = maybe_cache_resume_prompt_message(state, prompt_instruction)
    send(self(), :restart_container)
    state
  end

  defp initialize_lifecycle(
         state,
         _task,
         false,
         _prompt_instruction,
         _resume_container_id,
         _resume_session_id,
         prewarmed_container_id
       ) do
    maybe_start_from_prewarmed(state, prewarmed_container_id)
  end

  defp maybe_start_from_prewarmed(state, prewarmed_container_id)
       when is_binary(prewarmed_container_id) and prewarmed_container_id != "" do
    send(self(), :restart_prewarmed_container)
    %{state | container_id: prewarmed_container_id}
  end

  defp maybe_start_from_prewarmed(state, _prewarmed_container_id) do
    send(self(), :start_container)
    state
  end

  defp should_reconnect_sse?(state, pid) do
    current_sse_process?(state, pid) and
      not state.sse_reconnecting and
      task_active_for_sse_reconnect?(state)
  end

  defp current_sse_process?(%{sse_pid: pid}, pid) when is_pid(pid), do: true
  defp current_sse_process?(_, _), do: false

  defp task_active_for_sse_reconnect?(state) do
    state.session_id && state.container_port && state.status in [:prompting, :running]
  end

  defp valid_session_summary?(
         %{"files" => files, "additions" => additions, "deletions" => deletions} = summary
       )
       when is_integer(files) and is_integer(additions) and is_integer(deletions) do
    map_size(summary) == 3
  end

  defp valid_session_summary?(_summary), do: false

  defp update_task_status(state, attrs) do
    case state.task_repo.get_task(state.task_id) do
      %TaskSchema{} = task ->
        case state.task_repo.update_task_status(task, attrs) do
          {:ok, _task} = result ->
            result

          {:error, changeset} = result ->
            Logger.error(
              "TaskRunner: failed to update task status task_id=#{state.task_id} " <>
                "errors=#{inspect(changeset)}"
            )

            result
        end

      nil ->
        Logger.warning("TaskRunner: task #{state.task_id} not found in DB")
    end
  end

  defp fail_task(state, error) do
    cancel_flush_timer(state)
    from_task = state.task_repo.get_task(state.task_id)

    serialized_error = serialize_error(error)

    attrs = %{
      status: "failed",
      error: serialized_error,
      completed_at: DateTime.utc_now(),
      pending_question: nil
    }

    # Cache structured output parts (or plain text fallback) even on failure
    attrs = put_output_attrs(attrs, state)
    attrs = put_todo_attrs(attrs, state)

    update_task_status(state, attrs)
    broadcast_status_with_lifecycle(state, "failed", attrs, from_task)

    state.event_bus.emit(
      TaskFailed.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id,
        target_user_id: state.user_id,
        instruction: state.instruction,
        error: serialized_error
      })
    )

    notify_queue_terminal(state, :failed)
  end

  defp complete_task(state) do
    cancel_flush_timer(state)
    from_task = state.task_repo.get_task(state.task_id)

    attrs = %{
      status: "completed",
      completed_at: DateTime.utc_now(),
      pending_question: nil
    }

    # Cache structured output parts (or plain text fallback)
    attrs = put_output_attrs(attrs, state)
    attrs = put_todo_attrs(attrs, state)

    update_task_status(state, attrs)
    broadcast_status_with_lifecycle(state, "completed", attrs, from_task)

    state.event_bus.emit(
      TaskCompleted.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id,
        target_user_id: state.user_id,
        instruction: state.instruction
      })
    )

    notify_queue_terminal(state, :completed)
  end

  defp notify_queue_terminal(state, status) when status in [:completed, :failed, :cancelled] do
    state.queue_terminal_notifier.(state.user_id, state.task_id, status)
  rescue
    error ->
      Logger.warning(
        "TaskRunner: queue terminal notify failed for task #{state.task_id}: #{inspect(error)}"
      )

      :ok
  catch
    :exit, reason ->
      Logger.warning(
        "TaskRunner: queue terminal notify exited for task #{state.task_id}: #{inspect(reason)}"
      )

      :ok
  end

  # Prefer structured output_parts (JSON); fall back to plain output_text
  defp put_output_attrs(attrs, state) do
    case serialize_output_parts(state.output_parts) do
      nil when state.output_text != "" -> Map.put(attrs, :output, state.output_text)
      nil -> attrs
      json -> Map.put(attrs, :output, json)
    end
  end

  defp cleanup_container(%{container_id: nil}), do: :ok

  defp cleanup_container(state) do
    state.container_provider.stop(state.container_id)
  rescue
    error ->
      Logger.warning(
        "TaskRunner: cleanup_container failed for #{state.container_id}: #{inspect(error)}"
      )

      :ok
  end

  # Insert or update a part by its ID. If a part with the same ID
  # exists, replace it in-place. Otherwise append.
  defp upsert_output_part(parts, nil, entry) do
    parts ++ [entry]
  end

  defp upsert_output_part(parts, part_id, entry) do
    case Enum.find_index(parts, fn p -> p["id"] == part_id end) do
      nil -> parts ++ [entry]
      idx -> List.replace_at(parts, idx, entry)
    end
  end

  defp serialize_output_parts([]), do: nil

  defp serialize_output_parts(parts) do
    Jason.encode!(parts)
  end

  defp sanitize_fresh_start_reason({:docker_prepare_fresh_start_failed, exit_code, _output}) do
    "container repo sync failed (exit #{exit_code})"
  end

  defp sanitize_fresh_start_reason({:auth_refresh_failed, _provider}), do: "auth refresh failed"

  defp sanitize_fresh_start_reason(_), do: "internal preparation error"

  defp serialize_error(error) when is_binary(error), do: error

  defp serialize_error(%{"data" => %{"message" => msg}}), do: msg
  defp serialize_error(%{"message" => msg}), do: msg

  defp serialize_error(error) when is_map(error) do
    case Jason.encode(error) do
      {:ok, json} -> json
      _ -> inspect(error)
    end
  end

  defp serialize_error(error), do: inspect(error)

  defp broadcast_status(task_id, status, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_status_changed, task_id, status}
    )
  end

  defp broadcast_status_with_lifecycle(state, status, attrs, current_task) do
    to_task = lifecycle_target_task(current_task, attrs, status)

    from_state = lifecycle_state_from_task(current_task)
    to_state = lifecycle_state_from_task(to_task)
    container_id = Map.get(to_task, :container_id)

    broadcast_status(state.task_id, status, state.pubsub)

    broadcast_lifecycle_transition(
      state.task_id,
      from_state,
      to_state,
      container_id,
      state.pubsub
    )
  end

  defp lifecycle_target_task(nil, attrs, status) do
    attrs
    |> Map.new()
    |> Map.put_new(:status, status)
  end

  defp lifecycle_target_task(task, attrs, status) do
    task
    |> Map.from_struct()
    |> Map.merge(Map.new(attrs))
    |> Map.put(:status, status)
  end

  defp lifecycle_state_from_task(nil), do: :idle

  defp lifecycle_state_from_task(task) do
    SessionLifecyclePolicy.derive(%{
      status: Map.get(task, :status),
      container_id: Map.get(task, :container_id),
      container_port: Map.get(task, :container_port)
    })
  end

  defp broadcast_lifecycle_transition(task_id, from_state, to_state, container_id, pubsub) do
    Logger.debug(
      "Session lifecycle transition: #{from_state} -> #{to_state} [task=#{task_id}, container=#{container_id}]"
    )

    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:lifecycle_state_changed, task_id, from_state, to_state}
    )
  end

  defp broadcast_session_id_set(task_id, session_id, pubsub) do
    Phoenix.PubSub.broadcast(
      pubsub,
      "task:#{task_id}",
      {:task_session_id_set, task_id, session_id}
    )
  end

  defp broadcast_question_replied(state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, %{"type" => "question.replied"}}
    )
  end

  defp broadcast_question_rejected(state) do
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, %{"type" => "question.rejected"}}
    )
  end

  defp broadcast_container_stats(state) when is_binary(state.container_id) do
    case state.container_provider.stats(state.container_id) do
      {:ok, stats} ->
        mem_percent =
          if stats.memory_limit > 0,
            do: Float.round(stats.memory_usage / stats.memory_limit * 100, 1),
            else: 0.0

        payload = %{
          cpu_percent: stats.cpu_percent,
          memory_percent: mem_percent,
          memory_usage: stats.memory_usage,
          memory_limit: stats.memory_limit
        }

        Phoenix.PubSub.broadcast(
          state.pubsub,
          "task:#{state.task_id}",
          {:container_stats_updated, state.task_id, state.container_id, payload}
        )

      {:error, _} ->
        :ok
    end
  rescue
    _ -> :ok
  end

  defp broadcast_container_stats(_state), do: :ok

  defp clear_pending_question(state) do
    cancel_question_timeout(state)
    update_task_status(state, %{pending_question: nil})

    %{
      state
      | pending_question_request_id: nil,
        pending_question_data: nil,
        question_timeout_ref: nil
    }
  end

  defp auto_reject_empty_question(request_id, state) do
    if request_id do
      Logger.info(
        "TaskRunner: auto-rejecting empty question #{request_id} for task #{state.task_id}"
      )

      base_url = "http://localhost:#{state.container_port}"

      case state.opencode_client.reject_question(base_url, request_id, []) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "TaskRunner: auto-reject failed for #{request_id} on task #{state.task_id}: #{inspect(reason)}"
          )
      end
    end

    {:continue, state}
  end

  # Mark the question as rejected in DB but keep the data so the UI
  # can still display the card and let the user send an answer as a message
  defp mark_question_rejected(state) do
    cancel_question_timeout(state)

    case state.pending_question_data do
      %{} = pq ->
        rejected_data = Map.put(pq, "rejected", true)
        update_task_status(state, %{pending_question: rejected_data})

      _ ->
        :ok
    end

    %{
      state
      | pending_question_request_id: nil,
        pending_question_data: nil,
        question_timeout_ref: nil
    }
  end

  defp cache_answer_message(state, request_id, message, answers) do
    text =
      case message do
        msg when is_binary(msg) ->
          String.trim(msg)

        _ ->
          format_answers_for_cache(answers)
      end

    if String.trim(text) == "" do
      state
    else
      part_id = "user-answer-#{request_id}"
      entry = %{"type" => "user", "id" => part_id, "text" => text}
      output_parts = upsert_output_part(state.output_parts, part_id, entry)
      state = %{state | output_parts: output_parts}
      flush_output_to_db(state)
      state
    end
  end

  defp format_answers_for_cache(answers) when is_list(answers) do
    answers
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {answer_list, idx} ->
      cleaned = Enum.reject(answer_list, &(&1 in [nil, ""]))
      if cleaned == [], do: nil, else: "Answer #{idx}: #{Enum.join(cleaned, ", ")}"
    end)
    |> String.trim()
  end

  defp format_answers_for_cache(_), do: ""

  defp cancel_question_timeout(%{question_timeout_ref: nil}), do: :ok
  defp cancel_question_timeout(%{question_timeout_ref: ref}), do: Process.cancel_timer(ref)

  defp cancel_flush_timer(%{flush_ref: nil}), do: :ok
  defp cancel_flush_timer(%{flush_ref: ref}), do: Process.cancel_timer(ref)

  defp schedule_output_flush do
    interval = SessionsConfig.output_flush_interval_ms()
    Process.send_after(self(), :flush_output, interval)
  end

  defp flush_output_to_db(state) do
    attrs = %{}

    attrs =
      case serialize_output_parts(state.output_parts) do
        nil -> attrs
        json -> Map.put(attrs, :output, json)
      end

    attrs = put_todo_attrs(attrs, state)

    if attrs != %{} do
      update_task_status(state, attrs)
    end
  end

  defp parse_todo_event(properties) when is_map(properties) do
    case TodoList.from_sse_event(%{"properties" => properties}) do
      {:ok, %TodoList{} = todo_list} -> {:ok, TodoList.to_maps(todo_list)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_todo_event(_), do: {:error, :invalid_payload}

  defp broadcast_todo_update(task_id, todo_items, pubsub) do
    Phoenix.PubSub.broadcast(pubsub, "task:#{task_id}", {:todo_updated, task_id, todo_items})
  end

  defp put_todo_attrs(attrs, %{todo_items: []}), do: attrs

  defp put_todo_attrs(attrs, %{todo_items: todo_items}) when is_list(todo_items) do
    Map.put(attrs, :todo_items, %{"items" => todo_items})
  end

  defp merge_prior_resume_items([], current_items), do: current_items

  defp merge_prior_resume_items(prior_items, current_items) do
    current_ids = MapSet.new(current_items, & &1["id"])
    kept_prior = Enum.reject(prior_items, &(&1["id"] in current_ids))
    offset = length(kept_prior)

    shifted_current =
      Enum.map(current_items, fn item ->
        Map.update(item, "position", offset, &(&1 + offset))
      end)

    kept_prior ++ shifted_current
  end

  # Restore previously cached output parts from DB on resume.
  # The output column stores either a JSON array of structured parts
  # or a plain text string. We decode back to the internal map format
  # so new parts from the resumed session are appended correctly.
  defp restore_output_parts(nil), do: []
  defp restore_output_parts(""), do: []

  defp restore_output_parts(output) when is_binary(output) do
    case Jason.decode(output) do
      {:ok, parts} when is_list(parts) -> parts
      _ -> [%{"type" => "text", "id" => "cached-0", "text" => output}]
    end
  end

  defp restore_output_parts(_), do: []

  defp restore_todo_items(%{"items" => items}) when is_list(items), do: items
  defp restore_todo_items(_), do: []
end
