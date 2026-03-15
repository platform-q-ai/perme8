defmodule AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers do
  @moduledoc """
  Task execution, form management, question handling, and ticket lifecycle
  operations for the dashboard LiveView.

  Contains functions for creating/resuming/cancelling tasks, managing form
  state, handling question answers, processing task results, and ticket
  close/revert operations.
  """

  import Phoenix.Component, only: [assign: 3, to_form: 1]
  import Phoenix.LiveView, only: [push_event: 3, put_flash: 3]

  import AgentsWeb.DashboardLive.Helpers,
    only: [resumable_task?: 1, task_error_message: 1, last_user_message: 1, find_current_task: 2]

  import AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers
  import AgentsWeb.DashboardLive.Helpers.TicketDataHelpers
  import AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy

  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.TicketSessionLinker

  require Logger

  @doc "Returns the list of available session panel tabs."
  def session_tabs do
    [
      %{id: "chat", label: "Chat"},
      %{id: "ticket", label: "Ticket"}
    ]
  end

  def resolve_active_tab(params, has_ticket_tab?) do
    tab = params["tab"] || "chat"

    valid_tabs =
      Enum.map(
        if(has_ticket_tab?,
          do: session_tabs(),
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

  def clear_form(socket) do
    socket
    |> assign(:form, to_form(%{"instruction" => ""}))
    |> push_event("clear_input", %{})
  end

  def prefill_form(socket, text) do
    socket
    |> assign(:form, to_form(%{"instruction" => text}))
    |> push_event("restore_draft", %{text: text})
  end

  @doc "Routes a user message to the appropriate handler based on the session state machine's submission route."
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

  @doc "Creates a new task or resumes the current one, returning `{:ok, task}` or `{:error, reason}`."
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

  @doc "Processes task creation/resume results — subscribes to PubSub, updates assigns, and links tickets."
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

  def load_queue_state(user_id) do
    Sessions.get_queue_snapshot(user_id)
  catch
    :exit, _reason -> nil
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

    container_id = resolve_container_for_ticket(ticket, socket.assigns[:tasks_snapshot])

    maybe_delete_session(container_id, user.id)

    tasks_snapshot = maybe_remove_tasks(socket.assigns[:tasks_snapshot], container_id)

    tickets =
      map_ticket_tree(socket.assigns.tickets, fn t ->
        if t.number == number, do: %{t | state: "closed"}, else: t
      end)

    sessions = maybe_reject_session(socket.assigns.sessions, container_id)

    active_ticket_number =
      if socket.assigns.active_ticket_number == number,
        do: nil,
        else: socket.assigns.active_ticket_number

    tab = tab_after_ticket_close(socket.assigns, number)

    socket = maybe_clear_active_session(socket, container_id)

    socket
    |> assign(:tasks_snapshot, tasks_snapshot)
    |> assign(:tickets, tickets)
    |> assign(:sessions, sessions)
    |> assign(:active_ticket_number, active_ticket_number)
    |> assign(:active_session_tab, tab)
  end

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
end
