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
  alias Agents.Sessions.Domain.Entities.TodoList
  alias Agents.Sessions.Domain.Events.{TaskCompleted, TaskFailed, TaskCancelled}
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
    status: :starting,
    health_retries: 0,
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
    # Dependency injection
    container_provider: nil,
    opencode_client: nil,
    task_repo: nil,
    pubsub: nil,
    event_bus: nil
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

    # Resume context — if resuming, we already have container_id and session_id
    resume? = Keyword.get(opts, :resume, false)
    resume_container_id = Keyword.get(opts, :container_id)
    resume_session_id = Keyword.get(opts, :session_id)
    prompt_instruction = Keyword.get(opts, :prompt_instruction)

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
          health_retries: SessionsConfig.health_check_max_retries()
        }

        # Start the lifecycle — either resume or fresh start
        if resume? do
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

          send(self(), :restart_container)
          {:ok, state}
        else
          send(self(), :start_container)
          {:ok, state}
        end
    end
  end

  # ---- Question handling (called by LiveView via GenServer.call) ----

  @impl true
  def handle_call({:answer_question, request_id, answers}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.reply_question(base_url, request_id, answers, []) do
      :ok -> {:reply, :ok, clear_pending_question(state)}
      {:error, _} = error -> {:reply, error, state}
    end
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
  def handle_call({:send_message, message}, _from, state) do
    base_url = "http://localhost:#{state.container_port}"
    parts = [%{"type" => "text", "text" => message}]

    result = state.opencode_client.send_prompt_async(base_url, state.session_id, parts, [])
    {:reply, result, state}
  end

  # ---- Container Start ----

  @impl true
  def handle_info(:start_container, state) do
    image = state.image || SessionsConfig.image()

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

  # ---- Container Restart (resume path) ----

  @impl true
  def handle_info(:restart_container, state) do
    case state.container_provider.restart(state.container_id) do
      {:ok, %{port: port}} ->
        update_task_status(state, %{
          status: "starting",
          container_port: port
        })

        broadcast_status(state.task_id, "starting", state.pubsub)

        new_state = %{state | container_port: port, status: :health_check}
        send(self(), :wait_for_health_resume)
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
        case state.opencode_client.subscribe_events(base_url, self()) do
          {:ok, _pid} ->
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

  # ---- Session Create & Prompt ----

  @impl true
  def handle_info(:create_session, state) do
    base_url = "http://localhost:#{state.container_port}"

    case state.opencode_client.create_session(base_url, []) do
      {:ok, %{"id" => session_id}} ->
        # Persist session_id to DB for resume and message retrieval
        update_task_status(state, %{session_id: session_id})

        # Subscribe to SSE events
        case state.opencode_client.subscribe_events(base_url, self()) do
          {:ok, _pid} ->
            send(self(), :send_prompt)
            {:noreply, %{state | session_id: session_id, status: :prompting}}

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
        update_task_status(state, %{
          status: "running",
          started_at: DateTime.utc_now()
        })

        broadcast_status(state.task_id, "running", state.pubsub)

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
    # Broadcast all events to the LiveView via PubSub
    Phoenix.PubSub.broadcast(
      state.pubsub,
      "task:#{state.task_id}",
      {:task_event, state.task_id, event}
    )

    # Track user message IDs so we can filter their parts from output cache
    state = track_user_message_id(event, state)

    # Cache user message parts explicitly so follow-up prompts persist
    # across reconnects/reloads in the UI.
    if user_message_part?(event, state) do
      {:noreply, cache_user_message_part(event, state)}
    else
      handle_sdk_result(event, state)
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
  def handle_info({:DOWN, _ref, :process, _pid, reason}, state) when reason != :normal do
    fail_task(state, "SSE process crashed: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, :normal}, state) do
    {:noreply, state}
  end

  # ---- Cancellation ----

  @impl true
  def handle_info(:cancel, state) do
    cancel_flush_timer(state)
    cancel_question_timeout(state)

    if state.session_id && state.container_port do
      base_url = "http://localhost:#{state.container_port}"
      state.opencode_client.abort_session(base_url, state.session_id)
    end

    update_task_status(state, %{
      status: "cancelled",
      completed_at: DateTime.utc_now()
    })

    broadcast_status(state.task_id, "cancelled", state.pubsub)

    state.event_bus.emit(
      TaskCancelled.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id
      })
    )

    cleanup_container(state)
    {:stop, :normal, state}
  end

  # ---- Terminate (defensive cleanup) ----

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
        %{state | user_message_ids: MapSet.put(state.user_message_ids, msg_id)}

      _ ->
        state
    end
  end

  defp track_user_message_id(_event, state), do: state

  defp user_message_part?(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"messageID" => msg_id}}
         },
         state
       )
       when is_binary(msg_id) do
    MapSet.member?(state.user_message_ids, msg_id)
  end

  defp user_message_part?(
         %{
           "type" => "message.part.updated",
           "properties" => %{"part" => %{"messageId" => msg_id}}
         },
         state
       )
       when is_binary(msg_id) do
    MapSet.member?(state.user_message_ids, msg_id)
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
    parts = upsert_output_part(state.output_parts, part_id, entry)
    %{state | output_parts: parts}
  end

  defp cache_user_message_part(_event, state), do: state

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
    update_task_status(state, %{session_summary: summary})
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

  defp update_task_status(state, attrs) do
    case state.task_repo.get_task(state.task_id) do
      %TaskSchema{} = task ->
        state.task_repo.update_task_status(task, attrs)

      nil ->
        Logger.warning("TaskRunner: task #{state.task_id} not found in DB")
    end
  end

  defp fail_task(state, error) do
    cancel_flush_timer(state)

    serialized_error = serialize_error(error)

    attrs = %{
      status: "failed",
      error: serialized_error,
      completed_at: DateTime.utc_now()
    }

    # Cache structured output parts (or plain text fallback) even on failure
    attrs = put_output_attrs(attrs, state)
    attrs = put_todo_attrs(attrs, state)

    update_task_status(state, attrs)
    broadcast_status(state.task_id, "failed", state.pubsub)

    state.event_bus.emit(
      TaskFailed.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id,
        error: serialized_error
      })
    )

    cleanup_container(state)
  end

  defp complete_task(state) do
    cancel_flush_timer(state)

    attrs = %{
      status: "completed",
      completed_at: DateTime.utc_now()
    }

    # Cache structured output parts (or plain text fallback)
    attrs = put_output_attrs(attrs, state)
    attrs = put_todo_attrs(attrs, state)

    update_task_status(state, attrs)
    broadcast_status(state.task_id, "completed", state.pubsub)

    state.event_bus.emit(
      TaskCompleted.new(%{
        aggregate_id: state.task_id,
        actor_id: state.user_id,
        task_id: state.task_id,
        user_id: state.user_id
      })
    )

    cleanup_container(state)
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
