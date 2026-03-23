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
  alias Agents.Sessions.Domain.Events.{TaskCompleted, TaskFailed, TaskCancelled}
  alias Agents.Sessions.Infrastructure.SdkEventHandler
  alias Agents.Sessions.Infrastructure.Schemas.TaskSchema
  alias Agents.Sessions.Infrastructure.TaskRunner.ContainerLifecycle
  alias Agents.Sessions.Infrastructure.TaskRunner.OutputCache
  alias Agents.Sessions.Infrastructure.TaskRunner.QuestionHandler
  alias Agents.Sessions.Infrastructure.TaskRunner.SseEventRouter
  alias Agents.Sessions.Infrastructure.TaskRunner.TaskBroadcaster
  alias Agents.Sessions.Infrastructure.TaskRunner.TodoTracker

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
    queue_terminal_notifier: nil,
    setup_phase: nil,
    setup_instruction: nil,
    preserve_container: false
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
        Application.get_env(
          :agents,
          :container_provider,
          Agents.Sessions.Infrastructure.Adapters.DockerAdapter
        )
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
    prewarmed_container_port = Keyword.get(opts, :container_port)
    already_healthy = Keyword.get(opts, :already_healthy, false)
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
          setup_phase: if(resume?, do: :on_resume, else: :on_create),
          setup_instruction:
            if(resume?,
              do: SessionsConfig.setup_phase_instruction(:on_resume),
              else: SessionsConfig.setup_phase_instruction(:on_create)
            ),
          health_retries: SessionsConfig.health_check_max_retries()
        }

        session =
          Session.new(%{
            task_id: task_id,
            user_id: task.user_id,
            lifecycle_state: :starting
          })

        state = %{state | session: session}

        prewarmed_opts = %{
          container_id: prewarmed_container_id,
          container_port: prewarmed_container_port,
          already_healthy: already_healthy
        }

        state =
          initialize_lifecycle(
            state,
            task,
            resume?,
            prompt_instruction,
            resume_container_id,
            resume_session_id,
            prewarmed_opts
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
        state = do_cache_answer_message(state, request_id, message, answers)
        TaskBroadcaster.broadcast_question_replied(state.task_id, state.pubsub)
        {:reply, :ok, clear_pending_question(state)}

      {:error, reason} ->
        # If the question reply fails (e.g. opencode moved on or timed out
        # internally), fall back to sending the answer as a follow-up message
        # so the session continues seamlessly from the user's perspective.
        Logger.warning(
          "TaskRunner: reply_question failed for #{request_id} (#{inspect(reason)}), " <>
            "falling back to send_message for task #{state.task_id}"
        )

        fallback_result =
          if message do
            state.opencode_client.send_prompt_async(
              base_url,
              state.session_id,
              [%{"type" => "text", "text" => message}],
              []
            )
          else
            {:error, :no_message_for_fallback}
          end

        case fallback_result do
          :ok ->
            state = do_cache_answer_message(state, request_id, message, answers)
            TaskBroadcaster.broadcast_question_replied(state.task_id, state.pubsub)
            {:reply, :ok, clear_pending_question(state)}

          {:error, fallback_reason} ->
            Logger.warning(
              "TaskRunner: fallback send_prompt_async also failed for #{request_id} " <>
                "on task #{state.task_id}: #{inspect(fallback_reason)}"
            )

            {:reply, {:error, reason}, state}
        end
    end
  end

  def handle_call({:answer_question, request_id, answers}, from, state) do
    handle_call({:answer_question, request_id, answers, nil}, from, state)
  end

  @impl true
  def handle_call({:reject_question, request_id}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.reject_question(base_url, request_id, []) do
      :ok ->
        state = mark_question_rejected(state)
        TaskBroadcaster.broadcast_question_rejected(state.task_id, state.pubsub)
        {:reply, :ok, state}

      {:error, _} = error ->
        {:reply, error, state}
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
        do_cache_queued_user_message(state, message, command_payload)
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

        TaskBroadcaster.broadcast_status_with_lifecycle(
          state.task_id,
          "starting",
          %{
            status: "starting",
            container_id: container_id,
            container_port: port
          },
          from_task,
          state.pubsub
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

        TaskBroadcaster.broadcast_status_with_lifecycle(
          state.task_id,
          "starting",
          %{
            status: "starting",
            container_port: port
          },
          from_task,
          state.pubsub
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

        TaskBroadcaster.broadcast_status_with_lifecycle(
          state.task_id,
          "starting",
          %{
            status: "starting",
            container_port: port
          },
          from_task,
          state.pubsub
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
            queue_initial_prompt_phase(state)
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
          "Fresh warm start preparation failed: #{QuestionHandler.sanitize_fresh_start_reason(reason)}"
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
        TaskBroadcaster.broadcast_session_id_set(state.task_id, session_id, state.pubsub)

        # Subscribe to SSE events
        case subscribe_to_events(state) do
          {:ok, state} ->
            queue_initial_prompt_phase(state)
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
  def handle_info(:run_setup_phase, state) do
    base_url = "http://localhost:#{state.container_port}"
    parts = [%{type: "text", text: state.setup_instruction}]

    TaskBroadcaster.broadcast_setup_phase(
      state.task_id,
      state.setup_phase,
      state.setup_instruction,
      state.pubsub
    )

    case state.opencode_client.send_prompt_async(base_url, state.session_id, parts, []) do
      :ok ->
        send(self(), :send_prompt)
        {:noreply, state}

      {:error, reason} ->
        fail_task(state, "Setup phase failed: #{inspect(reason)}")
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

        TaskBroadcaster.broadcast_status_with_lifecycle(
          state.task_id,
          "running",
          %{status: "running"},
          from_task,
          state.pubsub
        )

        maybe_broadcast_container_stats(state)

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
    event_session_id = SseEventRouter.extract_session_id(event)

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
        {subtask_message_ids, child_session_ids} =
          SseEventRouter.track_subtask_message_id(
            event,
            state.subtask_message_ids,
            state.child_session_ids
          )

        state = %{
          state
          | subtask_message_ids: subtask_message_ids,
            child_session_ids: child_session_ids
        }

        state = do_cache_subtask_part(event, state)

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
    maybe_broadcast_container_stats(state)

    # Schedule the next flush if we're still running
    flush_ref = schedule_output_flush()
    {:noreply, %{state | flush_ref: flush_ref}}
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
    if ContainerLifecycle.current_sse_process?(state.sse_pid, pid) do
      fail_task(state, "SSE process crashed: #{inspect(reason)}")
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, :normal}, state) do
    if ContainerLifecycle.should_reconnect_sse?(
         state.sse_pid,
         state.sse_reconnecting,
         state.status,
         state.session_id,
         state.container_port,
         pid
       ) do
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

    TaskBroadcaster.broadcast_status_with_lifecycle(
      state.task_id,
      "cancelled",
      %{status: "cancelled"},
      from_task,
      state.pubsub
    )

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
        completed_state = complete_task(new_state)
        {:stop, :normal, completed_state}

      {:error, error_msg, new_state} ->
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
    TaskBroadcaster.broadcast_event(state.task_id, event, state.pubsub)

    # Track subtask message IDs so we can suppress their user messages
    {subtask_message_ids, child_session_ids} =
      SseEventRouter.track_subtask_message_id(
        event,
        state.subtask_message_ids,
        state.child_session_ids
      )

    state = %{
      state
      | subtask_message_ids: subtask_message_ids,
        child_session_ids: child_session_ids
    }

    # Track user message IDs so we can filter their parts from output cache
    user_message_ids =
      SseEventRouter.track_user_message_id(
        event,
        state.user_message_ids,
        state.subtask_message_ids
      )

    state = %{state | user_message_ids: user_message_ids}

    # Update Session entity via SdkEventHandler (domain events emitted here)
    state = update_session_from_sdk_event(state, event)

    # Route parts to appropriate caching: subtask -> user -> SDK dispatch
    cond do
      SseEventRouter.subtask_part?(event) ->
        {:noreply, do_cache_subtask_part(event, state)}

      SseEventRouter.user_message_part?(event, state.user_message_ids, state.subtask_message_ids) ->
        {:noreply, do_cache_user_message_part(event, state)}

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
  rescue
    e ->
      Logger.warning(
        "Session SDK event handling failed for task #{state.task_id}: #{Exception.message(e)}"
      )

      state
  end

  defp process_child_session_event(
         %{"type" => "session.status", "properties" => props} = event,
         child_session_id,
         state
       ) do
    status_type = get_in(props, ["status", "type"]) || props["status"]

    state =
      case status_type do
        "idle" ->
          subtask_part_id = Map.get(state.child_session_ids, child_session_id)

          %{
            state
            | output_parts: OutputCache.mark_subtask_done(state.output_parts, subtask_part_id)
          }

        _ ->
          state
      end

    TaskBroadcaster.broadcast_event(state.task_id, event, state.pubsub)
    {:noreply, state}
  end

  defp process_child_session_event(event, _child_session_id, state) do
    TaskBroadcaster.broadcast_event(state.task_id, event, state.pubsub)
    {:noreply, state}
  end

  # Cache the subtask part in output_parts. Subtask message tracking
  # (subtask_message_ids, child_session_ids) is handled separately by
  # SseEventRouter.track_subtask_message_id/3 in the calling functions.
  defp do_cache_subtask_part(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "subtask"} = part}
         },
         state
       ) do
    {entry, subtask_id} = OutputCache.build_subtask_entry(part)
    parts = OutputCache.upsert_part(state.output_parts, subtask_id, entry)
    %{state | output_parts: parts}
  end

  defp do_cache_subtask_part(_event, state), do: state

  defp do_cache_user_message_part(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"type" => "text", "text" => text} = part}
         },
         state
       )
       when is_binary(text) and text != "" do
    {entry, part_id} = OutputCache.build_user_message_entry(part)
    {parts, matched?} = OutputCache.promote_pending_user_part(state.output_parts, text, part_id)
    parts = if matched?, do: parts, else: OutputCache.upsert_part(parts, part_id, entry)
    %{state | output_parts: parts}
  end

  defp do_cache_user_message_part(_event, state), do: state

  defp do_cache_queued_user_message(state, message, command_payload \\ %{}) do
    case OutputCache.build_queued_user_entry(message, command_payload) do
      {entry, pending_id} ->
        output_parts = OutputCache.upsert_part(state.output_parts, pending_id, entry)
        state = %{state | output_parts: output_parts}
        flush_output_to_db(state)
        state

      nil ->
        state
    end
  end

  defp do_maybe_cache_resume_prompt(state, message) when is_binary(message) do
    if String.trim(message) == "" do
      state
    else
      do_cache_queued_user_message(state, message)
    end
  end

  defp do_maybe_cache_resume_prompt(state, _message), do: state

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
    tool_name = QuestionHandler.extract_tool_name(props)

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

  # Question requests — persist to DB and broadcast to LiveView.
  # No timeout: questions remain active until the user answers or dismisses them.
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

    new_state = %{
      state
      | pending_question_request_id: request_id,
        pending_question_data: question_data
    }

    {:question, new_state}
  end

  # Step progress events — parse and broadcast to LiveView, cache in state
  defp handle_sdk_event(
         %{"type" => "todo.updated", "properties" => props},
         state
       )
       when is_map(props) do
    case TodoTracker.parse_event(props) do
      {:ok, todo_items} ->
        merged_items = TodoTracker.merge_prior_items(state.prior_resume_items, todo_items)
        TaskBroadcaster.broadcast_todo_update(state.task_id, merged_items, state.pubsub)

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
    parts = OutputCache.upsert_part(state.output_parts, part_id, entry)
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
    parts = OutputCache.upsert_part(state.output_parts, part_id, entry)
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

    parts = OutputCache.upsert_part(state.output_parts, tool_id, entry)
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
    entry = OutputCache.build_tool_entry(part, tool_state, existing)
    parts = OutputCache.upsert_part(state.output_parts, tool_id, entry)
    {:continue, %{state | output_parts: parts}}
  end

  # session.updated — persist session summary (files changed, additions, deletions)
  defp handle_sdk_event(
         %{"type" => "session.updated", "properties" => %{"info" => %{"summary" => summary}}},
         state
       )
       when is_map(summary) do
    if QuestionHandler.valid_session_summary?(summary) do
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

  # ---- Private helpers ----

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

  defp queue_initial_prompt_phase(%{setup_instruction: instruction} = state)
       when is_binary(instruction) and instruction != "" do
    send(self(), :run_setup_phase)
    state
  end

  defp queue_initial_prompt_phase(state) do
    send(self(), :send_prompt)
    state
  end

  defp initialize_lifecycle(
         state,
         task,
         true,
         prompt_instruction,
         resume_container_id,
         resume_session_id,
         _prewarmed_opts
       ) do
    existing_parts = OutputCache.restore_parts(task.output)
    existing_todos = TodoTracker.restore_items(task.todo_items)

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

    state = do_maybe_cache_resume_prompt(state, prompt_instruction)
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
         prewarmed_opts
       ) do
    maybe_start_from_prewarmed(
      state,
      prewarmed_opts.container_id,
      prewarmed_opts.container_port,
      prewarmed_opts.already_healthy
    )
  end

  # Prewarmed container is already running and healthy — skip restart and health check
  defp maybe_start_from_prewarmed(state, prewarmed_container_id, prewarmed_container_port, true)
       when is_binary(prewarmed_container_id) and prewarmed_container_id != "" and
              is_integer(prewarmed_container_port) do
    send(self(), :prepare_fresh_start)
    %{state | container_id: prewarmed_container_id, container_port: prewarmed_container_port}
  end

  # Prewarmed container exists but may need restart — restart and health check
  defp maybe_start_from_prewarmed(state, prewarmed_container_id, _port, _already_healthy)
       when is_binary(prewarmed_container_id) and prewarmed_container_id != "" do
    send(self(), :restart_prewarmed_container)
    %{state | container_id: prewarmed_container_id}
  end

  # No prewarmed container — cold start
  defp maybe_start_from_prewarmed(state, _prewarmed_container_id, _port, _already_healthy) do
    send(self(), :start_container)
    state
  end

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

    serialized_error = OutputCache.serialize_error(error)

    attrs = %{
      status: "failed",
      error: serialized_error,
      completed_at: DateTime.utc_now(),
      pending_question: nil
    }

    # Cache structured output parts (or plain text fallback) even on failure
    attrs = OutputCache.put_output_attrs(attrs, state.output_parts, state.output_text)
    attrs = TodoTracker.put_attrs(attrs, state.todo_items)

    update_task_status(state, attrs)

    TaskBroadcaster.broadcast_status_with_lifecycle(
      state.task_id,
      "failed",
      attrs,
      from_task,
      state.pubsub
    )

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
    attrs = OutputCache.put_output_attrs(attrs, state.output_parts, state.output_text)
    attrs = TodoTracker.put_attrs(attrs, state.todo_items)

    update_task_status(state, attrs)

    TaskBroadcaster.broadcast_status_with_lifecycle(
      state.task_id,
      "completed",
      attrs,
      from_task,
      state.pubsub
    )

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

    %{state | preserve_container: true}
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

  defp maybe_broadcast_container_stats(%{container_id: container_id} = state)
       when is_binary(container_id) do
    case state.container_provider.stats(container_id) do
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

        TaskBroadcaster.broadcast_container_stats(
          state.task_id,
          container_id,
          payload,
          state.pubsub
        )

      {:error, _} ->
        :ok
    end
  rescue
    _ -> :ok
  end

  defp maybe_broadcast_container_stats(_state), do: :ok

  defp cleanup_container(%{container_id: nil}), do: :ok

  defp cleanup_container(%{preserve_container: true}), do: :ok

  defp cleanup_container(state) do
    state.container_provider.stop(state.container_id)
  rescue
    error ->
      Logger.warning(
        "TaskRunner: cleanup_container failed for #{state.container_id}: #{inspect(error)}"
      )

      :ok
  end

  defp clear_pending_question(state) do
    update_task_status(state, %{pending_question: nil})

    %{
      state
      | pending_question_request_id: nil,
        pending_question_data: nil
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

  # Mark the question as rejected in DB so reconnect won't restore the
  # dismissed card, then clear pending state from the GenServer.
  defp mark_question_rejected(state) do
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
        pending_question_data: nil
    }
  end

  defp do_cache_answer_message(state, request_id, message, answers) do
    case OutputCache.build_answer_entry(request_id, message, answers) do
      {entry, part_id} ->
        output_parts = OutputCache.upsert_part(state.output_parts, part_id, entry)
        state = %{state | output_parts: output_parts}
        flush_output_to_db(state)
        state

      nil ->
        state
    end
  end

  defp cancel_flush_timer(%{flush_ref: nil}), do: :ok
  defp cancel_flush_timer(%{flush_ref: ref}), do: Process.cancel_timer(ref)

  defp schedule_output_flush do
    interval = SessionsConfig.output_flush_interval_ms()
    Process.send_after(self(), :flush_output, interval)
  end

  defp flush_output_to_db(state) do
    attrs = %{}

    attrs =
      case OutputCache.serialize_parts(state.output_parts) do
        nil -> attrs
        json -> Map.put(attrs, :output, json)
      end

    attrs = TodoTracker.put_attrs(attrs, state.todo_items)

    if attrs != %{} do
      update_task_status(state, attrs)
    end
  end
end
