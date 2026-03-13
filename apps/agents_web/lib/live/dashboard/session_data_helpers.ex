defmodule AgentsWeb.DashboardLive.SessionDataHelpers do
  @moduledoc false

  import Phoenix.Component, only: [assign: 2, assign: 3, to_form: 1]
  import Phoenix.LiveView, only: [push_event: 3, put_flash: 3]
  import AgentsWeb.DashboardLive.Helpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Entities.TicketLifecycleEvent
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy

  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.Index, as: DashboardIndex
  alias AgentsWeb.DashboardLive.SessionStateMachine
  alias AgentsWeb.DashboardLive.TicketSessionLinker

  require Logger

  @optimistic_stale_seconds 120

  def resolve_active_tab(params, has_ticket_tab?) do
    tab = params["tab"] || "chat"

    valid_tabs =
      Enum.map(
        if(has_ticket_tab?,
          do: DashboardIndex.session_tabs(),
          else: [%{id: "chat"}]
        ),
        & &1.id
      )

    if tab in valid_tabs, do: tab, else: "chat"
  end

  def resolve_active_ticket_number(
        %{"new" => "true"},
        _selected_container_id,
        _sessions,
        _tickets,
        current
      ) do
    current
  end

  def resolve_active_ticket_number(_params, selected_container_id, sessions, tickets, _current)
      when is_binary(selected_container_id) and selected_container_id != "" do
    find_ticket_number_for_selected_session(sessions, tickets, selected_container_id)
  end

  def resolve_active_ticket_number(
        _params,
        _selected_container_id,
        _sessions,
        _tickets,
        current
      ),
      do: current

  def tasks_snapshot_or_reload(socket) do
    socket.assigns[:tasks_snapshot] || Sessions.list_tasks(socket.assigns.current_scope.user.id)
  end

  def resolve_selected_container_id(%{"new" => "true"}, _sessions), do: nil

  def resolve_selected_container_id(%{"container" => container_id}, sessions)
      when is_binary(container_id) do
    if Enum.any?(sessions, &(&1.container_id == container_id)) do
      container_id
    else
      default_container_id(sessions)
    end
  end

  def resolve_selected_container_id(_params, sessions), do: default_container_id(sessions)

  def default_container_id([first | _]), do: first.container_id
  def default_container_id([]), do: nil

  def resolve_current_task(%{"new" => "true"}, _tasks, _selected_container_id), do: nil

  def resolve_current_task(_params, tasks, selected_container_id) do
    find_current_task(tasks, selected_container_id)
  end

  def delete_queued_task_by_id(task_id, user_id) do
    case Sessions.get_task(task_id, user_id) do
      {:ok, task} when is_binary(task.container_id) and task.container_id != "" ->
        Sessions.delete_session(task.container_id, user_id)

      {:ok, _task} ->
        Sessions.delete_task(task_id, user_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  def resolve_queued_delete(task_id, container_id, user_id) do
    cond do
      is_binary(container_id) and container_id != "" and
          not String.starts_with?(container_id, "task:") ->
        Sessions.delete_session(container_id, user_id)

      is_binary(task_id) and task_id != "" ->
        delete_queued_task_by_id(task_id, user_id)

      true ->
        {:error, :not_found}
    end
  end

  def clear_deleted_selection(socket, task_id, container_id) do
    active_deleted? = socket.assigns.active_container_id == container_id
    current_deleted? = socket.assigns.current_task && socket.assigns.current_task.id == task_id

    if active_deleted? or current_deleted? do
      socket
      |> assign(:active_container_id, nil)
      |> assign(:current_task, nil)
      |> assign(:events, [])
      |> assign_session_state()
    else
      socket
    end
  end

  def maybe_put_container(params, container_id)
      when is_binary(container_id) and container_id != "" do
    Map.put(params, "container", container_id)
  end

  def maybe_put_container(params, _container_id), do: params

  def maybe_put_new(params, true), do: Map.put(params, "new", true)
  def maybe_put_new(params, _), do: params

  def assign_session_state(socket) do
    assign(socket,
      session_title: nil,
      session_model: nil,
      session_tokens: nil,
      session_cost: nil,
      session_summary: nil,
      parent_session_id: nil,
      child_session_ids: MapSet.new(),
      output_parts: [],
      pending_question: nil,
      confirmed_user_messages: [],
      optimistic_user_messages: [],
      user_message_ids: MapSet.new(),
      subtask_message_ids: MapSet.new(),
      todo_items: [],
      queued_messages: []
    )
  end

  # Clears the instruction textarea via both LiveView form state and a push event
  # to the hook (necessary because phx-update="ignore" prevents server assigns from
  # reaching the DOM).
  def clear_form(socket) do
    socket
    |> assign(:form, to_form(%{"instruction" => ""}))
    |> push_event("clear_input", %{})
  end

  # Pre-fills the instruction textarea via both LiveView form state and a push event
  # to the hook (necessary because phx-update="ignore" prevents server assigns from
  # reaching the DOM).
  def prefill_form(socket, text) do
    socket
    |> assign(:form, to_form(%{"instruction" => text}))
    |> push_event("restore_draft", %{text: text})
  end

  def route_message_submission(:follow_up, socket, instruction, _ticket_number, _ticket) do
    send_message_to_running_task(socket, instruction)
  end

  def route_message_submission(:new_or_resume, socket, instruction, ticket_number, ticket) do
    socket =
      if resumable_task?(socket.assigns.current_task) do
        append_optimistic_user_message(socket, instruction)
      else
        socket
      end

    socket
    |> run_or_resume_task(instruction, ticket_number, ticket)
    |> handle_task_result(socket)
  end

  def route_message_submission(:blocked, socket, _instruction, _ticket_number, _ticket) do
    {:noreply, put_flash(socket, :error, "Cannot submit message in current state")}
  end

  def send_message_to_running_task(socket, instruction) do
    correlation_key = Ecto.UUID.generate()
    queued_at = DateTime.utc_now()

    queued_msg = %{
      id: correlation_key,
      correlation_key: correlation_key,
      content: instruction,
      status: "pending",
      queued_at: queued_at
    }

    send(
      self(),
      {:dispatch_follow_up_message, socket.assigns.current_task.id, instruction, correlation_key,
       queued_at}
    )

    {:noreply,
     socket
     |> assign(
       :queued_messages,
       merge_queued_messages(socket.assigns.queued_messages, [queued_msg])
     )
     |> broadcast_optimistic_queue_snapshot()
     |> clear_form()
     |> push_event("scroll_to_bottom", %{})}
  end

  def normalize_hydrated_queue_entry(entry) when is_map(entry) do
    id = entry["id"] || entry["correlation_key"]
    content = entry["content"]

    if is_binary(id) and is_binary(content) do
      %{
        id: id,
        correlation_key: entry["correlation_key"] || id,
        content: content,
        status: entry["status"] || "pending",
        queued_at: parse_hydrated_datetime(entry["queued_at"])
      }
    else
      nil
    end
  end

  def normalize_hydrated_queue_entry(_), do: nil

  def parse_hydrated_datetime(nil), do: DateTime.utc_now()

  def parse_hydrated_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  def parse_hydrated_datetime(_), do: DateTime.utc_now()

  def normalize_hydrated_new_session_entry(entry) when is_map(entry) do
    id = entry["id"]
    instruction = entry["instruction"]

    if is_binary(id) and is_binary(instruction) do
      %{
        id: id,
        instruction: instruction,
        image: entry["image"] || Sessions.default_image(),
        status: entry["status"] || "queued",
        queued_at: parse_hydrated_datetime(entry["queued_at"])
      }
    else
      nil
    end
  end

  def normalize_hydrated_new_session_entry(_), do: nil

  def merge_optimistic_new_sessions(existing, incoming) do
    (existing ++ incoming)
    |> Enum.reduce(%{}, fn entry, acc ->
      case entry[:id] do
        id when is_binary(id) -> Map.put(acc, id, entry)
        _ -> acc
      end
    end)
    |> Map.values()
    |> Enum.sort_by(fn entry ->
      case entry[:queued_at] do
        %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
        _ -> 0
      end
    end)
  end

  def remove_optimistic_new_session(entries, client_id) do
    Enum.reject(entries, &(&1.id == client_id))
  end

  # An optimistic entry is stale if it was queued more than 2 minutes ago.
  # At that point the backend has either succeeded (real session exists) or
  # failed (the DOWN handler should have cleaned up).
  def stale_optimistic_entry?(%{queued_at: %DateTime{} = queued_at}) do
    DateTime.diff(DateTime.utc_now(), queued_at, :second) > @optimistic_stale_seconds
  end

  def stale_optimistic_entry?(_), do: true

  # An optimistic entry already has a real session if any existing session's
  # title matches the entry's instruction text.
  def already_has_real_session?(%{instruction: instruction}, sessions)
      when is_binary(instruction) do
    trimmed = String.trim(instruction)
    Enum.any?(sessions, fn session -> String.trim(session.title || "") == trimmed end)
  end

  def already_has_real_session?(_, _), do: false

  def normalize_ordered_ticket_numbers(values) when is_list(values) do
    values
    |> Enum.map(&Integer.parse(to_string(&1)))
    |> Enum.filter(&match?({_, ""}, &1))
    |> Enum.map(fn {n, _} -> n end)
  end

  def normalize_ordered_ticket_numbers(_), do: []

  def merge_queued_messages(existing, incoming) do
    (existing ++ incoming)
    |> Enum.reduce(%{}, fn msg, acc ->
      key = msg[:correlation_key] || msg[:id] || "fallback-#{msg[:content]}"
      Map.put(acc, key, msg)
    end)
    |> Map.values()
    |> Enum.sort_by(fn msg ->
      case msg[:queued_at] do
        %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
        _ -> 0
      end
    end)
  end

  def maybe_sync_optimistic_queue_snapshot(socket, previous_queue) do
    current_queue = Map.get(socket.assigns, :queued_messages, [])

    if previous_queue != current_queue do
      broadcast_optimistic_queue_snapshot(socket)
    else
      socket
    end
  end

  def broadcast_optimistic_queue_snapshot(socket) do
    case socket.assigns.current_task do
      %{id: task_id} ->
        payload = %{
          user_id: socket.assigns.current_scope.user.id,
          task_id: task_id,
          entries: serialize_queued_messages(socket.assigns.queued_messages)
        }

        push_event(socket, "optimistic_queue_set", payload)

      _ ->
        socket
    end
  end

  def clear_optimistic_queue_snapshot(socket, task_id) when is_binary(task_id) do
    push_event(socket, "optimistic_queue_clear", %{
      user_id: socket.assigns.current_scope.user.id,
      task_id: task_id
    })
  end

  def clear_optimistic_queue_snapshot(socket, _task_id), do: socket

  def clear_new_task_monitor(socket, client_id) do
    {monitor_ref, _existing} =
      Enum.find(socket.assigns.new_task_monitors, {nil, nil}, fn {_ref, tracked_client_id} ->
        tracked_client_id == client_id
      end)

    if is_reference(monitor_ref) do
      Process.demonitor(monitor_ref, [:flush])

      assign(
        socket,
        :new_task_monitors,
        Map.delete(socket.assigns.new_task_monitors, monitor_ref)
      )
    else
      socket
    end
  end

  def maybe_flash_new_task_down(socket, :normal), do: socket

  def maybe_flash_new_task_down(socket, reason) do
    put_flash(socket, :error, "Session creation failed: #{inspect(reason)}")
  end

  def broadcast_optimistic_new_sessions_snapshot(socket) do
    payload = %{
      user_id: socket.assigns.current_scope.user.id,
      entries: serialize_optimistic_new_sessions(socket.assigns.optimistic_new_sessions)
    }

    push_event(socket, "optimistic_new_sessions_set", payload)
  end

  def serialize_optimistic_new_sessions(entries) do
    Enum.map(entries, fn entry ->
      %{
        id: entry[:id],
        instruction: entry[:instruction],
        image: entry[:image],
        status: entry[:status] || "queued",
        queued_at: serialize_queued_datetime(entry[:queued_at])
      }
    end)
  end

  def serialize_queued_messages(messages) do
    Enum.map(messages, fn msg ->
      %{
        id: msg[:id],
        correlation_key: msg[:correlation_key],
        content: msg[:content],
        status: msg[:status] || "pending",
        queued_at: serialize_queued_datetime(msg[:queued_at])
      }
    end)
  end

  def serialize_queued_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  def serialize_queued_datetime(_), do: DateTime.utc_now() |> DateTime.to_iso8601()

  def append_optimistic_user_message(socket, message) do
    append_optimistic_part(socket, message, :user_pending)
  end

  def append_answer_submitted_message(socket, message) do
    append_optimistic_part(socket, message, :answer_submitted)
  end

  def append_optimistic_part(socket, message, tag) do
    trimmed = String.trim(message)
    optimistic_id = "optimistic-#{System.unique_integer([:positive])}"
    updated = socket.assigns.optimistic_user_messages ++ [trimmed]
    parts = socket.assigns.output_parts ++ [{tag, optimistic_id, trimmed}]

    socket
    |> assign(:optimistic_user_messages, updated)
    |> assign(:output_parts, parts)
  end

  def remove_answer_submitted_part(socket, message) do
    trimmed = String.trim(message)

    parts =
      Enum.reject(socket.assigns.output_parts, fn
        {:answer_submitted, _id, text} -> String.trim(text) == trimmed
        _ -> false
      end)

    optimistic =
      List.delete(socket.assigns.optimistic_user_messages, trimmed)

    socket
    |> assign(:output_parts, parts)
    |> assign(:optimistic_user_messages, optimistic)
  end

  def toggle_selection(current, label, true = _multiple) do
    if label in current, do: List.delete(current, label), else: current ++ [label]
  end

  def toggle_selection(current, label, false = _single) do
    if label in current, do: [], else: [label]
  end

  def build_question_answers(pending) do
    Enum.zip(pending.selected, pending.custom_text)
    |> Enum.map(fn {selected, custom} ->
      custom_trimmed = String.trim(custom)
      if custom_trimmed != "", do: selected ++ [custom_trimmed], else: selected
    end)
  end

  def format_question_answer_as_message(pending, answers) do
    Enum.zip(pending.questions, answers)
    |> Enum.map_join("\n", fn {question, answer_list} ->
      header = question["header"] || "Question"
      "Re: #{header} — #{Enum.join(answer_list, ", ")}"
    end)
  end

  def submit_rejected_question(socket, pending, task_id) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    Sessions.send_message(task_id, message)
    |> handle_question_result_basic(socket, pending, "Failed to send message — please try again")
  end

  def submit_active_question(socket, pending, task_id) do
    answers = build_question_answers(pending)
    message = format_question_answer_as_message(pending, answers)

    send(self(), {:answer_question_async, task_id, pending.request_id, answers, message})

    socket
    |> append_answer_submitted_message(message)
    |> assign(:pending_question, nil)
  end

  def handle_question_result_basic(:ok, socket, _pending, _error_msg) do
    assign(socket, :pending_question, nil)
  end

  def handle_question_result_basic({:error, :task_not_running}, socket, pending, _error_msg) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    socket
    |> assign(:pending_question, nil)
    |> prefill_form(message)
    |> put_flash(:info, "Session ended. Your answer is in the input — submit to resume.")
  end

  def handle_question_result_basic({:error, _}, socket, _pending, error_msg) do
    socket |> assign(:pending_question, nil) |> put_flash(:error, error_msg)
  end

  def run_or_resume_task(socket, instruction, ticket_number, ticket \\ nil) do
    user = socket.assigns.current_scope.user
    current_task = socket.assigns.current_task

    if socket.assigns.composing_new || is_nil(current_task) do
      instruction = ensure_ticket_reference(instruction, ticket_number, ticket)

      Sessions.create_task(%{
        instruction: instruction,
        user_id: user.id,
        image: socket.assigns.selected_image
      })
    else
      Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
    end
  end

  def handle_task_result({:ok, task}, socket) do
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    is_resume = match?(%{id: id} when id == task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, task)
      |> assign(:parent_session_id, task.session_id)
      |> assign(:active_container_id, task.container_id)
      |> assign(:composing_new, false)
      |> clear_form()

    socket =
      if is_resume do
        socket
        |> assign(:events, [])
        |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
        socket
        |> assign(:events, [])
        |> assign_session_state()
      end

    sessions = upsert_session_from_task(socket.assigns.sessions, task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    # Persist ticket-task FK and reload tickets from DB so the link
    # is immediately reflected in the UI (Bug 2 fix). This replaces
    # the old maybe_link_ticket_to_task + stale enrich_all pattern.
    socket = TicketSessionLinker.link_and_refresh(socket, task)

    {:noreply,
     socket
     |> assign(:sessions, sessions)
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
     |> push_event("scroll_to_bottom", %{})
     |> push_event("focus_input", %{})}
  end

  def handle_task_result({:error, reason}, socket) do
    {:noreply, put_flash(socket, :error, task_error_message(reason))}
  end

  def do_cancel_task(task, socket, flash_message \\ "Task cancelled") do
    case perform_cancel_task(task, socket) do
      {:ok, socket} ->
        {:noreply, put_flash(socket, :info, flash_message)}

      {:error, socket} ->
        {:noreply, socket}
    end
  end

  # Cancels the task and updates all socket assigns (sessions, tasks_snapshot,
  # tickets enrichment, sticky warm IDs, draft restoration). Returns the updated
  # socket for callers that need to chain additional operations (e.g. unlinking
  # a ticket FK after cancel).
  def perform_cancel_task(task, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.cancel_task(task.id, user.id) do
      :ok ->
        updated = fetch_cancelled_task(task, user.id)
        sessions = upsert_session_from_task(socket.assigns.sessions, updated)

        sticky_warm_task_ids =
          derive_sticky_warm_task_ids(
            sessions,
            socket.assigns[:queue_state] || default_queue_state(),
            socket.assigns[:sticky_warm_task_ids] || MapSet.new()
          )

        tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], updated)
        instruction = recover_instruction(updated, task)

        {:ok,
         socket
         |> assign(:current_task, updated)
         |> assign(:parent_session_id, updated.session_id)
         |> assign(:sessions, sessions)
         |> assign(:tasks_snapshot, tasks_snapshot)
         |> assign(
           :tickets,
           TicketEnrichmentPolicy.enrich_all(
             socket.assigns.tickets,
             tasks_snapshot,
             &SessionLifecyclePolicy.derive/1
           )
         )
         |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
         |> push_event("restore_draft", %{text: instruction})}

      {:error, _reason} ->
        {:error, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  def fetch_cancelled_task(task, user_id) do
    case Sessions.get_task(task.id, user_id) do
      {:ok, t} -> t
      _ -> Map.put(task, :status, "cancelled")
    end
  end

  # Restore the most recent user message (not the original instruction).
  # For tasks that ran, decode their output to find follow-up messages.
  # Fall back to the original instruction for queued tasks with no output.
  def recover_instruction(updated_task, original_task) do
    case Map.get(updated_task, :output) do
      output when is_binary(output) and output != "" ->
        output
        |> EventProcessor.decode_cached_output()
        |> last_user_message()

      _ ->
        nil
    end || Map.get(updated_task, :instruction) || Map.get(original_task, :instruction, "")
  end

  def resolve_changed_task(true, updated_current_task, _task_id, _status, _socket),
    do: updated_current_task

  def resolve_changed_task(false, _updated_current_task, task_id, status, socket) do
    snapshot_task =
      (socket.assigns[:tasks_snapshot] || [])
      |> Enum.find(&(&1.id == task_id))

    if snapshot_task do
      snapshot_task
      |> Map.put(:status, status)
      |> Map.put(:lifecycle_state, lifecycle_state_for_task_status(snapshot_task, status))
    else
      %{id: task_id, status: status, lifecycle_state: status}
    end
  end

  # Only modify current session UI state (output_parts, pending_question,
  # queued_messages) when the status change is for the currently viewed task.
  # Non-current task completions should not wipe the active session's UI.
  def apply_status_change_to_ui(socket, false, _status, task_id),
    do: clear_optimistic_queue_snapshot(socket, task_id)

  def apply_status_change_to_ui(socket, true, status, task_id)
      when status in ["completed", "failed"] do
    socket
    |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
    |> assign(:pending_question, nil)
    |> assign(:queued_messages, [])
    |> clear_optimistic_queue_snapshot(task_id)
  end

  def apply_status_change_to_ui(socket, true, "cancelled", task_id) do
    socket
    |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
    |> assign(:pending_question, nil)
    |> clear_optimistic_queue_snapshot(task_id)
  end

  def apply_status_change_to_ui(socket, true, _status, _task_id), do: socket

  def maybe_sync_status_from_session_event(
        socket,
        %{"type" => "session.status"} = event,
        task_id
      ) do
    status_type = get_in(event, ["properties", "status", "type"])

    event_session_id =
      get_in(event, ["properties", "sessionID"]) || get_in(event, ["properties", "session_id"])

    parent_session_id = Map.get(socket.assigns, :parent_session_id)

    case status_type do
      "idle"
      when is_nil(parent_session_id) or is_nil(event_session_id) or
             event_session_id == parent_session_id ->
        request_task_refresh(socket, task_id)

      _ ->
        socket
    end
  end

  def maybe_sync_status_from_session_event(socket, _event, _task_id), do: socket

  def request_task_refresh(socket, task_id) when is_binary(task_id) do
    refreshing = socket.assigns[:refreshing_task_ids] || MapSet.new()

    if MapSet.member?(refreshing, task_id) do
      socket
    else
      user_id = socket.assigns.current_scope.user.id
      caller = self()

      Task.start(fn ->
        try do
          send(caller, {:task_refreshed, task_id, Sessions.get_task(task_id, user_id)})
        rescue
          error ->
            Logger.warning(
              "request_task_refresh failed for task_id=#{task_id}: #{inspect(error)}"
            )

            send(caller, {:task_refreshed, task_id, {:error, error}})
        end
      end)

      assign(socket, :refreshing_task_ids, MapSet.put(refreshing, task_id))
    end
  end

  def request_task_refresh(socket, _task_id), do: socket

  def derive_sticky_warm_task_ids(sessions, queue_state, previous_sticky) do
    queued_session_ids =
      sessions
      |> Enum.filter(&(&1.latest_status == "queued"))
      |> Enum.map(& &1.latest_task_id)
      |> Enum.filter(&is_binary/1)
      |> MapSet.new()

    queued_real_container_ids =
      sessions
      |> Enum.filter(&(&1.latest_status == "queued" and has_real_container?(&1)))
      |> Enum.map(& &1.latest_task_id)
      |> Enum.filter(&is_binary/1)
      |> MapSet.new()

    warm_limit = Map.get(queue_state || %{}, :warm_cache_limit, 0)

    queue_window_ids =
      queue_state
      |> Map.get(:queued, [])
      |> Enum.take(warm_limit)
      |> Enum.map(& &1.id)
      |> Enum.filter(&is_binary/1)

    queue_signaled_ids =
      (Map.get(queue_state || %{}, :warm_task_ids, []) || []) ++
        (Map.get(queue_state || %{}, :warming_task_ids, []) || []) ++ queue_window_ids

    queue_signaled_ids = queue_signaled_ids |> Enum.filter(&is_binary/1) |> MapSet.new()

    previous_still_queued =
      previous_sticky
      |> MapSet.new()
      |> MapSet.intersection(queued_session_ids)

    queue_signaled_ids
    |> MapSet.union(previous_still_queued)
    |> MapSet.union(queued_real_container_ids)
  end

  def has_real_container?(%{container_id: container_id}) when is_binary(container_id) do
    container_id != "" and not String.starts_with?(container_id, "task:")
  end

  def has_real_container?(_), do: false

  # Reload tickets from the database with enrichment from the current tasks snapshot.
  def reload_tickets(socket) do
    user = socket.assigns.current_scope.user

    ticket_opts =
      case socket.assigns[:tasks_snapshot] do
        tasks when is_list(tasks) and tasks != [] -> [tasks: tasks]
        _ -> []
      end

    Tickets.list_project_tickets(user.id, ticket_opts)
  end

  def apply_ticket_closed(socket, number) do
    user = socket.assigns.current_scope.user
    ticket = find_ticket_by_number(socket.assigns.tickets, number)

    # Resolve the container_id for session cleanup. We try three sources:
    # 1. Enrichment-derived associated_container_id (set for active tasks)
    # 2. Persisted associated_task_id → look up container_id from tasks_snapshot
    #    (works for terminal tasks where enrichment no longer sets container_id)
    # 3. nil (no session to clean up)
    container_id = resolve_container_for_ticket(ticket, socket.assigns[:tasks_snapshot])

    # Best-effort session cleanup -- Docker failure must not block the UI update
    maybe_delete_session(container_id, user.id)

    # Clean up tasks_snapshot for the destroyed session so stale entries
    # don't keep the ticket "linked" to a deleted task.
    tasks_snapshot = maybe_remove_tasks(socket.assigns[:tasks_snapshot], container_id)

    tickets =
      map_ticket_tree(socket.assigns.tickets, fn t ->
        if t.number == number, do: %{t | state: "closed"}, else: t
      end)

    # Remove the associated session from the sessions list
    sessions = maybe_reject_session(socket.assigns.sessions, container_id)

    active_ticket_number =
      if socket.assigns.active_ticket_number == number,
        do: nil,
        else: socket.assigns.active_ticket_number

    # Switch back to chat tab if we just closed the viewed ticket
    tab = tab_after_ticket_close(socket.assigns, number)

    # Clear active selection if we just destroyed the viewed session
    socket = maybe_clear_active_session(socket, container_id)

    socket
    |> assign(:tasks_snapshot, tasks_snapshot)
    |> assign(:tickets, tickets)
    |> assign(:sessions, sessions)
    |> assign(:active_ticket_number, active_ticket_number)
    |> assign(:active_session_tab, tab)
  end

  # Resolves the container_id for a ticket's associated session.
  # Tries enrichment-derived container_id first, then falls back to looking
  # up the persisted task_id in the in-memory tasks_snapshot.
  def resolve_container_for_ticket(nil, _tasks_snapshot), do: nil

  def resolve_container_for_ticket(ticket, tasks_snapshot) do
    # 1. Try enrichment-derived value (set for active/non-terminal tasks)
    case ticket.associated_container_id do
      cid when is_binary(cid) and cid != "" ->
        cid

      _ ->
        # 2. Fall back to persisted task_id → look up container from snapshot
        resolve_container_from_task_id(ticket.associated_task_id, tasks_snapshot)
    end
  end

  def resolve_container_from_task_id(nil, _tasks_snapshot), do: nil
  def resolve_container_from_task_id(_task_id, nil), do: nil
  def resolve_container_from_task_id(_task_id, tasks) when not is_list(tasks), do: nil

  def resolve_container_from_task_id(task_id, tasks_snapshot) do
    case Enum.find(tasks_snapshot, &(&1.id == task_id)) do
      nil -> nil
      task -> Map.get(task, :container_id)
    end
  end

  def map_ticket_tree(tickets, fun) when is_list(tickets) do
    Enum.map(tickets, fn ticket ->
      updated = fun.(ticket)
      %{updated | sub_tickets: map_ticket_tree(updated.sub_tickets || [], fun)}
    end)
  end

  def all_tickets(tickets) when is_list(tickets) do
    Enum.flat_map(tickets, fn ticket -> [ticket | all_tickets(ticket.sub_tickets || [])] end)
  end

  def find_ticket_by_number(tickets, number) when is_integer(number) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.number == number))
  end

  def find_ticket_by_number(_tickets, _number), do: nil

  def maybe_revert_optimistic_ticket(socket, nil), do: socket

  def maybe_revert_optimistic_ticket(socket, ticket_number) do
    tickets =
      update_ticket_by_number(socket.assigns.tickets, ticket_number, fn t ->
        %{t | task_status: nil, associated_task_id: nil, session_state: "idle"}
      end)

    assign(socket, :tickets, tickets)
  end

  def update_ticket_lifecycle_assigns(socket, ticket_id, to_stage, transitioned_at) do
    tickets =
      map_ticket_tree(socket.assigns.tickets, fn ticket ->
        if lifecycle_ticket_match?(ticket, ticket_id) do
          %{ticket | lifecycle_stage: to_stage, lifecycle_stage_entered_at: transitioned_at}
        else
          ticket
        end
      end)

    assign(socket, :tickets, tickets)
  end

  def update_ticket_by_number(tickets, number, update_fn) when is_list(tickets) do
    Enum.map(tickets, fn ticket ->
      cond do
        ticket.number == number ->
          update_fn.(ticket)

        is_list(ticket.sub_tickets) and ticket.sub_tickets != [] ->
          %{ticket | sub_tickets: update_ticket_by_number(ticket.sub_tickets, number, update_fn)}

        true ->
          ticket
      end
    end)
  end

  def lifecycle_ticket_match?(ticket, ticket_id) do
    candidate_ids = [Map.get(ticket, :id), Map.get(ticket, :number)]
    ticket_id in candidate_ids
  end

  def maybe_apply_ticket_lifecycle_fixture(socket, %{"fixture" => fixture})
      when is_binary(fixture) do
    case ticket_lifecycle_fixture_tickets(fixture) do
      [] ->
        assign(socket, :fixture, fixture)

      tickets ->
        active_ticket_number = tickets |> List.first() |> then(&(&1 && &1.number))

        socket
        |> assign(:fixture, fixture)
        |> assign(:sessions, [])
        |> assign(:tasks_snapshot, [])
        |> assign(:tickets, tickets)
        |> assign(:active_ticket_number, active_ticket_number)
    end
  end

  def maybe_apply_ticket_lifecycle_fixture(socket, _params) do
    assign(socket, :fixture, nil)
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress",
        external_id: "in-progress-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -1800, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_in_progress_duration") do
    [
      lifecycle_fixture_ticket(402, "Lifecycle in progress duration",
        external_id: "in-progress-duration-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_all_stages") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    [
      {5001, "open"},
      {5002, "ready"},
      {5003, "in_progress"},
      {5004, "in_review"},
      {5005, "ci_testing"},
      {5006, "deployed"},
      {5007, "closed"}
    ]
    |> Enum.with_index()
    |> Enum.map(fn {{number, stage}, idx} ->
      lifecycle_fixture_ticket(number, "Lifecycle stage #{stage}",
        lifecycle_stage: stage,
        lifecycle_stage_entered_at: DateTime.add(now, -3600 * (idx + 1), :second)
      )
    end)
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_timeline") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 1,
        ticket_id: 430,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -18_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 2,
        ticket_id: 430,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -12_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 3,
        ticket_id: 430,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(430, "Timeline fixture",
        external_id: "timeline-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_relative_durations") do
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    events = [
      TicketLifecycleEvent.new(%{
        id: 11,
        ticket_id: 431,
        from_stage: nil,
        to_stage: "open",
        transitioned_at: DateTime.add(now, -10_000, :second),
        trigger: "sync"
      }),
      TicketLifecycleEvent.new(%{
        id: 12,
        ticket_id: 431,
        from_stage: "open",
        to_stage: "ready",
        transitioned_at: DateTime.add(now, -9_000, :second),
        trigger: "manual"
      }),
      TicketLifecycleEvent.new(%{
        id: 13,
        ticket_id: 431,
        from_stage: "ready",
        to_stage: "in_progress",
        transitioned_at: DateTime.add(now, -6_000, :second),
        trigger: "manual"
      })
    ]

    [
      lifecycle_fixture_ticket(431, "Relative durations fixture",
        external_id: "relative-durations-ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(now, -6_000, :second),
        lifecycle_events: events
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_realtime_transition") do
    [
      lifecycle_fixture_ticket(402, "Realtime transition ticket",
        lifecycle_stage: "in_progress",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -7200, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_newly_synced") do
    [
      lifecycle_fixture_ticket(450, "Newly synced ticket",
        external_id: "newly-synced-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -300, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_closed") do
    [
      lifecycle_fixture_ticket(451, "Closed ticket fixture",
        external_id: "closed-ticket",
        lifecycle_stage: "closed",
        lifecycle_stage_entered_at: DateTime.add(DateTime.utc_now(), -3600, :second)
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets("ticket_lifecycle_no_events") do
    [
      lifecycle_fixture_ticket(452, "No events ticket fixture",
        external_id: "default-lifecycle-ticket",
        lifecycle_stage: "open",
        lifecycle_stage_entered_at: nil,
        lifecycle_events: []
      )
    ]
  end

  def ticket_lifecycle_fixture_tickets(_fixture), do: []

  def lifecycle_fixture_ticket(number, title, attrs) do
    defaults = %{
      id: number,
      number: number,
      title: title,
      state: "open",
      labels: ["agents"],
      lifecycle_stage: "open",
      lifecycle_stage_entered_at: DateTime.utc_now() |> DateTime.truncate(:second),
      lifecycle_events: [],
      sub_tickets: [],
      position: 0,
      session_state: "idle",
      task_status: nil,
      associated_task_id: nil,
      associated_container_id: nil
    }

    defaults
    |> Map.merge(Map.new(attrs))
    |> Ticket.new()
  end

  def find_parent_ticket(_tickets, %{parent_ticket_id: nil}), do: nil

  def find_parent_ticket(tickets, %{parent_ticket_id: parent_id}) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.id == parent_id))
  end

  def upsert_task_snapshot(tasks, nil), do: tasks

  def upsert_task_snapshot(tasks, task) when is_list(tasks) do
    {matches, rest} = Enum.split_with(tasks, &(&1.id == task.id))

    merged =
      case matches do
        [existing | _] -> Map.merge(existing, task)
        [] -> task
      end

    [merged | rest]
  end

  def upsert_task_snapshot(_tasks, task), do: [task]

  # Remove tasks belonging to a container from the snapshot. Matches tasks
  # by their real container_id (from the DB) or by synthetic container_ids
  # produced by derive_container_id (e.g. "task:<task_id>").
  def remove_tasks_for_container(tasks, _container_id) when not is_list(tasks), do: tasks

  def remove_tasks_for_container(tasks, container_id) when is_binary(container_id) do
    Enum.reject(tasks, fn task ->
      task_cid = Map.get(task, :container_id)
      task_id = Map.get(task, :id)

      task_cid == container_id or
        (is_binary(task_id) and "task:#{task_id}" == container_id)
    end)
  end

  # Helper functions for close_ticket to reduce cyclomatic complexity
  def maybe_delete_session(container_id, user_id) when is_binary(container_id) do
    Sessions.delete_session(container_id, user_id)
  rescue
    _ -> :ok
  end

  def maybe_delete_session(_container_id, _user_id), do: :ok

  def maybe_remove_tasks(tasks_snapshot, container_id) when is_binary(container_id) do
    remove_tasks_for_container(tasks_snapshot, container_id)
  end

  def maybe_remove_tasks(tasks_snapshot, _container_id), do: tasks_snapshot

  def maybe_reject_session(sessions, container_id) when is_binary(container_id) do
    Enum.reject(sessions, &(&1.container_id == container_id))
  end

  def maybe_reject_session(sessions, _container_id), do: sessions

  def tab_after_ticket_close(assigns, number) do
    if assigns.active_ticket_number == number and assigns.active_session_tab == "ticket",
      do: "chat",
      else: assigns.active_session_tab
  end

  def maybe_clear_active_session(socket, container_id) when is_binary(container_id) do
    if socket.assigns.active_container_id == container_id do
      socket
      |> assign(:active_container_id, nil)
      |> assign(:current_task, nil)
      |> assign(:events, [])
      |> assign_session_state()
    else
      socket
    end
  end

  def maybe_clear_active_session(socket, _container_id), do: socket

  # Removes tasks for a container from the snapshot, asynchronously unlinks
  def update_task_lifecycle_state(tasks, _task_id, _lifecycle_state) when not is_list(tasks),
    do: tasks

  def update_task_lifecycle_state(tasks, task_id, lifecycle_state) do
    Enum.map(tasks, fn
      %{id: ^task_id} = task -> Map.put(task, :lifecycle_state, lifecycle_state)
      task -> task
    end)
  end

  def update_session_lifecycle_state(sessions, _task_id, _lifecycle_state)
      when not is_list(sessions),
      do: sessions

  def update_session_lifecycle_state(sessions, task_id, lifecycle_state) do
    Enum.map(sessions, fn
      %{latest_task_id: ^task_id} = session -> Map.put(session, :lifecycle_state, lifecycle_state)
      session -> session
    end)
  end

  def lifecycle_state_to_string(state) when is_atom(state), do: Atom.to_string(state)
  def lifecycle_state_to_string(state) when is_binary(state), do: state
  def lifecycle_state_to_string(_state), do: "idle"

  def lifecycle_state_for_task_status(task, status) do
    task
    |> Map.put(:status, status)
    |> Map.put(:lifecycle_state, nil)
    |> SessionStateMachine.state_from_task()
    |> lifecycle_state_to_string()
  end

  def find_ticket_number_for_container(tickets, container_id) do
    case Enum.find(all_tickets(tickets), &(&1.associated_container_id == container_id)) do
      %{number: number} -> number
      _ -> nil
    end
  end

  def find_ticket_number_for_selected_session(sessions, tickets, container_id) do
    case find_ticket_number_for_container(tickets, container_id) do
      number when is_integer(number) ->
        number

      _ ->
        extract_ticket_number_from_session(sessions, tickets, container_id)
    end
  end

  def extract_ticket_number_from_session(sessions, tickets, container_id) do
    session = Enum.find(sessions, &(&1.container_id == container_id))
    title = is_map(session) && Map.get(session, :title)

    with title when is_binary(title) <- title,
         number when is_integer(number) and number > 0 <-
           Tickets.extract_ticket_number(title),
         true <- Enum.any?(all_tickets(tickets), &(&1.number == number)) do
      number
    else
      _ -> nil
    end
  end

  def next_active_ticket_number([], _current), do: nil

  def next_active_ticket_number(tickets, current) do
    flattened_tickets = all_tickets(tickets)

    case Enum.find(flattened_tickets, &(&1.number == current)) do
      %{number: number} -> number
      _ -> flattened_tickets |> List.first() |> then(&(&1 && &1.number))
    end
  end

  def merge_unassigned_active_tasks(sessions, tasks) do
    unassigned =
      tasks
      |> Enum.filter(&(active_task?(&1) and is_nil(&1.container_id)))
      |> Enum.map(fn task ->
        %{
          container_id: "task:" <> task.id,
          task_count: 1,
          latest_status: task.status,
          latest_task_id: task.id,
          latest_error: task.error,
          title: task.instruction,
          image: task.image,
          latest_at: task.inserted_at,
          created_at: task.inserted_at,
          todo_items: task.todo_items || %{"items" => []}
        }
      end)

    sessions
    |> Kernel.++(unassigned)
    |> sort_sessions_for_sidebar()
  end

  def sort_sessions_for_sidebar(sessions) do
    Enum.sort_by(sessions, fn session ->
      {running_session?(session), -latest_at_unix(session)}
    end)
  end

  def running_session?(%{latest_status: status}) do
    status in ["pending", "starting", "running", "queued", "awaiting_feedback"]
  end

  def running_session?(_), do: false

  def latest_at_unix(%{latest_at: %DateTime{} = dt}), do: DateTime.to_unix(dt, :microsecond)

  def latest_at_unix(%{latest_at: %NaiveDateTime{} = dt}),
    do: NaiveDateTime.to_gregorian_seconds(dt)

  def latest_at_unix(_), do: 0

  def load_queue_state(user_id) do
    Sessions.get_queue_state(user_id)
  catch
    :exit, _reason -> default_queue_state()
  end

  def default_queue_state do
    %{
      running: 0,
      queued: [],
      awaiting_feedback: [],
      concurrency_limit: 2,
      warm_cache_limit: 2,
      warm_task_ids: [],
      warming_task_ids: []
    }
  end

  def subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  def update_session_todo_items(sessions, container_id, todo_maps) do
    Enum.map(sessions, fn
      %{container_id: ^container_id} = session ->
        Map.put(session, :todo_items, %{"items" => todo_maps})

      session ->
        session
    end)
  end

  def upsert_session_from_task(sessions, task) do
    task_id = Map.get(task, :id)
    task_container_id = Map.get(task, :container_id)
    session_update = build_session_from_task(task, task_id, task_container_id)

    {existing, rest} = split_matching_sessions(sessions, task_id, task_container_id)

    merged =
      case existing do
        [first | _] ->
          # Only overwrite fields that the task actually provides.
          # This prevents minimal task maps (e.g. from a status-only update)
          # from clobbering real session data with defaults.
          safe_update = drop_default_fields(session_update, task)
          Map.merge(first, safe_update)

        [] ->
          session_update
      end

    sort_sessions_for_sidebar([merged | rest])
  end

  # When the task map is minimal (status-only update), only carry forward
  # the fields it actually has — don't let build_session_from_task defaults
  # overwrite real session data.
  def drop_default_fields(session_update, task) do
    fields_to_keep =
      [:latest_status, :latest_task_id, :latest_error, :latest_at]

    # Only include container_id if the task actually has one
    fields_to_keep =
      if is_binary(Map.get(task, :container_id)) and Map.get(task, :container_id) != "",
        do: [:container_id | fields_to_keep],
        else: fields_to_keep

    # Only include title/image/timestamps if the task has real instruction data
    fields_to_keep =
      if Map.has_key?(task, :instruction),
        do: [
          :title,
          :image,
          :created_at,
          :started_at,
          :completed_at,
          :session_summary,
          :todo_items | fields_to_keep
        ],
        else: fields_to_keep

    Map.take(session_update, fields_to_keep)
  end

  def build_session_from_task(task, task_id, task_container_id) do
    %{
      container_id: derive_container_id(task_container_id, task_id),
      task_count: 1,
      latest_status: Map.get(task, :status, "queued"),
      latest_task_id: task_id,
      latest_error: Map.get(task, :error),
      title: Map.get(task, :instruction, "New session"),
      image: Map.get(task, :image, Sessions.default_image()),
      latest_at: Map.get(task, :updated_at) || Map.get(task, :inserted_at) || DateTime.utc_now(),
      created_at: Map.get(task, :inserted_at) || DateTime.utc_now(),
      started_at: Map.get(task, :started_at),
      completed_at: Map.get(task, :completed_at),
      session_summary: Map.get(task, :session_summary),
      todo_items: Map.get(task, :todo_items) || %{"items" => []}
    }
  end

  def derive_container_id(cid, _task_id) when is_binary(cid) and cid != "", do: cid
  def derive_container_id(_cid, task_id) when is_binary(task_id), do: "task:" <> task_id
  def derive_container_id(_cid, _task_id), do: "task:unknown"

  def split_matching_sessions(sessions, task_id, task_container_id) do
    Enum.split_with(sessions, fn session ->
      matches_container?(session, task_container_id) or session.latest_task_id == task_id
    end)
  end

  def matches_container?(session, cid) when is_binary(cid) and cid != "",
    do: session.container_id == cid

  def matches_container?(_session, _cid), do: false

  def hydrate_task_for_session(task, user_id) when is_map(task) do
    task_id = Map.get(task, :id)

    complete? =
      is_binary(task_id) and
        (is_binary(Map.get(task, :instruction)) or is_binary(Map.get(task, :container_id)))

    cond do
      complete? ->
        task

      is_binary(task_id) and match?({:ok, _}, Ecto.UUID.cast(task_id)) ->
        case Sessions.get_task(task_id, user_id) do
          {:ok, persisted} -> persisted
          _ -> task
        end

      true ->
        task
    end
  end

  def hydrate_task_for_session(task, _user_id), do: task

  def resolve_new_task_ack_task(task, user_id, optimistic_entry) do
    hydrated = hydrate_task_for_session(task, user_id)

    cond do
      is_binary(Map.get(hydrated, :instruction)) ->
        hydrated

      is_map(optimistic_entry) and is_binary(optimistic_entry[:instruction]) ->
        find_task_by_instruction(user_id, optimistic_entry[:instruction]) || hydrated

      true ->
        hydrated
    end
  end

  def find_task_by_instruction(user_id, instruction) do
    user_id
    |> Sessions.list_tasks()
    |> Enum.filter(&(&1.instruction == instruction))
    |> Enum.sort_by(
      fn task ->
        case task.inserted_at do
          %DateTime{} = dt -> DateTime.to_unix(dt, :microsecond)
          %NaiveDateTime{} = dt -> NaiveDateTime.to_gregorian_seconds(dt)
          _ -> 0
        end
      end,
      :desc
    )
    |> List.first()
  end

  def parse_ticket_number_param(%{"ticket_number" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> nil
    end
  end

  def parse_ticket_number_param(_), do: nil

  # Returns true when the ticket's associated task matches the current task,
  # meaning a follow-up message should go to that task. Returns false when
  # the ticket has no task or is linked to a different task — in that case
  # a new task should be created for the ticket.
  def ticket_owns_current_task?(nil, _current_task), do: false
  def ticket_owns_current_task?(_ticket, nil), do: false

  def ticket_owns_current_task?(%{associated_task_id: task_id}, %{id: current_id})
      when is_binary(task_id) and is_binary(current_id) do
    task_id == current_id
  end

  def ticket_owns_current_task?(_ticket, _current_task), do: false

  def ensure_ticket_reference(instruction, nil, _ticket), do: instruction

  def ensure_ticket_reference(instruction, _ticket_number, %Ticket{} = ticket) do
    context = Tickets.build_ticket_context(ticket)

    if Tickets.extract_ticket_number(instruction) do
      "#{instruction}\n\n#{context}"
    else
      "##{ticket.number} #{instruction}\n\n#{context}"
    end
  end

  def ensure_ticket_reference(instruction, ticket_number, nil) do
    if Tickets.extract_ticket_number(instruction) do
      instruction
    else
      "##{ticket_number} #{instruction}"
    end
  end
end
