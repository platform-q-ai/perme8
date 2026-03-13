defmodule AgentsWeb.DashboardLive.PubSubHandlers do
  @moduledoc "Processes PubSub messages (task events, queue updates, ticket syncs) for the dashboard LiveView."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [clear_flash: 1, put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers

  import AgentsWeb.DashboardLive.Helpers,
    only: [task_error_message: 1]

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Entities.TodoList
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets.Domain.Events.TicketStageChanged
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy

  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.TicketSessionLinker

  require Logger

  def task_event(task_id, event, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id} ->
        previous_queue = Map.get(socket.assigns, :queued_messages, [])

        socket =
          event
          |> EventProcessor.process_event(socket)
          |> maybe_sync_status_from_session_event(event, task_id)
          |> maybe_sync_optimistic_queue_snapshot(previous_queue)

        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def answer_question_async(task_id, request_id, answers, message, socket) do
    case Sessions.answer_question(task_id, request_id, answers, message) do
      :ok ->
        {:noreply, socket}

      {:error, :task_not_running} ->
        {:noreply,
         socket
         |> remove_answer_submitted_part(message)
         |> prefill_form(message)
         |> put_flash(:info, "Session ended. Your answer is in the input — submit to resume.")}

      {:error, _} ->
        {:noreply,
         socket
         |> remove_answer_submitted_part(message)
         |> put_flash(:error, "Failed to submit answer — please try again")}
    end
  end

  def todo_updated(task_id, todo_items, socket) do
    case socket.assigns.current_task do
      %{id: ^task_id, container_id: container_id} when is_list(todo_items) ->
        todo_list = TodoList.from_maps(todo_items)

        sessions =
          update_session_todo_items(
            socket.assigns.sessions,
            container_id,
            TodoList.to_maps(todo_list)
          )

        {:noreply,
         socket
         |> assign(:todo_items, EventProcessor.todo_items_for_assigns(todo_list))
         |> assign(:sessions, sessions)}

      _ ->
        {:noreply, socket}
    end
  end

  def task_status_changed(task_id, status, socket) do
    current_task = socket.assigns.current_task
    is_current_task = is_map(current_task) and current_task.id == task_id

    updated_current_task =
      if is_current_task do
        current_task
        |> Map.put(:status, status)
        |> Map.put(:lifecycle_state, lifecycle_state_for_task_status(current_task, status))
      else
        current_task
      end

    changed_task =
      resolve_changed_task(is_current_task, updated_current_task, task_id, status, socket)

    cid =
      if(is_current_task && updated_current_task && updated_current_task.container_id,
        do: updated_current_task.container_id,
        else: socket.assigns.active_container_id
      )

    sessions = upsert_session_from_task(socket.assigns.sessions, changed_task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], changed_task)

    # Synchronous enrichment is needed so ticket lane placement reflects
    # the status change immediately (e.g. failed task → ticket returns to
    # triage). The subsequent task_refreshed_ok provides authoritative
    # enrichment with fresh DB data.
    tickets =
      TicketEnrichmentPolicy.enrich_all(
        socket.assigns.tickets,
        tasks_snapshot,
        &SessionLifecyclePolicy.derive/1
      )

    socket =
      socket
      |> assign(:current_task, updated_current_task)
      |> assign(:parent_session_id, updated_current_task && updated_current_task.session_id)
      |> assign(:active_container_id, cid)
      |> assign(:sessions, sessions)
      |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
      |> assign(:tasks_snapshot, tasks_snapshot)
      |> assign(:tickets, tickets)
      |> request_task_refresh(task_id)
      |> apply_status_change_to_ui(is_current_task, status, task_id)

    {:noreply, socket}
  end

  def lifecycle_state_changed(task_id, to_state, socket) do
    lifecycle_state = lifecycle_state_to_string(to_state)

    updated_current_task =
      case socket.assigns.current_task do
        %{id: ^task_id} = current_task -> Map.put(current_task, :lifecycle_state, lifecycle_state)
        other -> other
      end

    tasks_snapshot =
      update_task_lifecycle_state(socket.assigns[:tasks_snapshot] || [], task_id, lifecycle_state)

    sessions =
      update_session_lifecycle_state(socket.assigns.sessions, task_id, lifecycle_state)

    # Lifecycle state changes don't affect ticket enrichment — skip enrich_all.
    {:noreply,
     socket
     |> assign(:current_task, updated_current_task)
     |> assign(:sessions, sessions)
     |> assign(:tasks_snapshot, tasks_snapshot)}
  end

  def container_stats_updated(container_id, stats, socket) do
    {:noreply,
     assign(
       socket,
       :container_stats,
       Map.put(socket.assigns.container_stats, container_id, stats)
     )}
  end

  # Tagged async result from per-session auth refresh (success)
  def tagged_auth_refresh_ok(ref, task_id, new_task, socket) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")

    socket =
      assign(socket, :auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))

    # Only update the detail pane if this is the currently viewed session
    socket =
      if match?(%{id: ^task_id}, socket.assigns.current_task) do
        is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

        socket =
          socket
          |> assign(:current_task, new_task)
          |> assign(:parent_session_id, new_task.session_id)
          |> assign(:events, [])
          |> clear_form()

        if is_resume do
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
        else
          assign_session_state(socket)
        end
      else
        socket
      end

    sessions = upsert_session_from_task(socket.assigns.sessions, new_task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], new_task)

    {:noreply,
     socket
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
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)}
  end

  # Tagged async result from per-session auth refresh (error)
  def tagged_auth_refresh_error(ref, task_id, reason, socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))
     |> put_flash(:error, "Session refresh failed: #{task_error_message(reason)}")}
  end

  def new_task_created_ok(client_id, task, socket) do
    user = socket.assigns.current_scope.user
    optimistic_entry = Enum.find(socket.assigns.optimistic_new_sessions, &(&1.id == client_id))
    task = resolve_new_task_ack_task(task, user.id, optimistic_entry)

    # Subscribe to this task's PubSub topic so we receive status updates
    # (starting, running, completed, etc.). Must happen before the refresh
    # request below to avoid missing broadcasts after the refresh reads.
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    sessions = upsert_session_from_task(socket.assigns.sessions, task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    # Persist ticket-task FK and reload tickets from DB via the linker.
    # This replaces the old maybe_link_ticket_to_task + manual reload pattern.
    socket = TicketSessionLinker.link_and_refresh(socket, task)

    socket =
      socket
      |> clear_new_task_monitor(client_id)
      |> assign(
        :optimistic_new_sessions,
        remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
      )
      |> broadcast_optimistic_new_sessions_snapshot()
      |> assign(
        :pending_ticket_starts,
        Map.delete(socket.assigns.pending_ticket_starts, client_id)
      )
      |> assign(:sessions, sessions)
      |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)

    # The task may have already been promoted (queued -> pending -> running)
    # before we subscribed above, so any PubSub broadcasts from the
    # QueueManager/TaskRunner were lost. Refresh from DB to catch up.
    {:noreply, request_task_refresh(socket, task.id)}
  end

  def new_task_created_error(client_id, reason, socket) do
    # If this was a ticket-initiated start, revert the optimistic ticket update
    {ticket_number, pending} = Map.pop(socket.assigns.pending_ticket_starts, client_id)

    socket =
      if ticket_number do
        tickets =
          update_ticket_by_number(socket.assigns.tickets, ticket_number, fn t ->
            %{t | task_status: nil, associated_task_id: nil, session_state: "idle"}
          end)

        assign(socket, :tickets, tickets)
      else
        socket
      end

    {:noreply,
     socket
     |> clear_new_task_monitor(client_id)
     |> assign(
       :optimistic_new_sessions,
       remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
     )
     |> broadcast_optimistic_new_sessions_snapshot()
     |> assign(:pending_ticket_starts, pending)
     |> put_flash(:error, task_error_message(reason))}
  end

  # Untagged async result (from run_or_resume_task — not auth refresh)
  def untagged_async_ok(ref, new_task, socket) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")
    is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, new_task)
      |> assign(:parent_session_id, new_task.session_id)
      |> assign(:events, [])
      |> clear_form()
      |> clear_flash()

    socket =
      if is_resume do
        socket
        |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
        assign_session_state(socket)
      end

    sessions = upsert_session_from_task(socket.assigns.sessions, new_task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], new_task)

    {:noreply,
     socket
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
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)}
  end

  def untagged_async_error(ref, reason, socket) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(:error, task_error_message(reason))}
  end

  def down(ref, reason, socket) do
    case Map.pop(socket.assigns.new_task_monitors, ref) do
      {nil, _monitors} ->
        {:noreply, socket}

      {client_id, monitors} ->
        # Revert optimistic ticket update if this was a ticket-initiated start
        {ticket_number, pending} = Map.pop(socket.assigns.pending_ticket_starts, client_id)
        socket = maybe_revert_optimistic_ticket(socket, ticket_number)

        {:noreply,
         socket
         |> assign(:new_task_monitors, monitors)
         |> assign(:pending_ticket_starts, pending)
         |> assign(
           :optimistic_new_sessions,
           remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
         )
         |> broadcast_optimistic_new_sessions_snapshot()
         |> maybe_flash_new_task_down(reason)}
    end
  end

  def queue_snapshot(snapshot, socket) do
    {:noreply,
     socket
     |> assign(:queue_snapshot, snapshot)
     |> assign(:queue_state, QueueSnapshot.to_legacy_map(snapshot))}
  end

  def queue_updated(user_id, queue_state, socket) do
    if user_id == socket.assigns.current_scope.user.id do
      sticky_warm_task_ids =
        derive_sticky_warm_task_ids(
          socket.assigns.sessions,
          queue_state,
          socket.assigns[:sticky_warm_task_ids] || MapSet.new()
        )

      # Queue metadata doesn't change ticket state — skip enrich_all.
      {:noreply,
       socket
       |> assign(:queue_state, queue_state)
       |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)}
    else
      {:noreply, socket}
    end
  end

  def tickets_synced(socket) do
    socket = TicketSessionLinker.refresh_tickets(socket)
    tickets = socket.assigns.tickets

    # Re-derive active ticket number from the currently selected session
    active_ticket_number =
      case socket.assigns[:active_container_id] do
        cid when is_binary(cid) and cid != "" ->
          find_ticket_number_for_selected_session(
            socket.assigns.sessions,
            tickets,
            cid
          ) || next_active_ticket_number(tickets, socket.assigns[:active_ticket_number])

        _ ->
          next_active_ticket_number(tickets, socket.assigns[:active_ticket_number])
      end

    {:noreply, assign(socket, :active_ticket_number, active_ticket_number)}
  end

  def ticket_stage_changed(ticket_id, to_stage, transitioned_at, socket) do
    {:noreply, update_ticket_lifecycle_assigns(socket, ticket_id, to_stage, transitioned_at)}
  end

  def ticket_stage_changed_event(%TicketStageChanged{} = event, socket) do
    transitioned_at = event.occurred_at || DateTime.utc_now() |> DateTime.truncate(:second)

    {:noreply,
     update_ticket_lifecycle_assigns(socket, event.ticket_id, event.to_stage, transitioned_at)}
  end

  def ticket_sync_finished(socket) do
    {:noreply, assign(socket, :syncing_tickets, false)}
  end

  def task_refreshed_ok(task_id, task, socket) do
    refreshing = MapSet.delete(socket.assigns[:refreshing_task_ids] || MapSet.new(), task_id)
    sessions = upsert_session_from_task(socket.assigns.sessions, task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    current_task =
      case socket.assigns.current_task do
        %{id: ^task_id} -> task
        other -> other
      end

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], task)

    {:noreply,
     socket
     |> assign(:refreshing_task_ids, refreshing)
     |> assign(:current_task, current_task)
     |> assign(:parent_session_id, current_task && current_task.session_id)
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
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)}
  end

  def task_refreshed_error(task_id, socket) do
    {:noreply,
     assign(
       socket,
       :refreshing_task_ids,
       MapSet.delete(socket.assigns[:refreshing_task_ids] || MapSet.new(), task_id)
     )}
  end
end
