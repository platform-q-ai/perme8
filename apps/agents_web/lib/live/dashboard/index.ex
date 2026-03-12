defmodule AgentsWeb.DashboardLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.DashboardLive.Components.SessionComponents
  import AgentsWeb.DashboardLive.Components.QueueLaneComponents
  import AgentsWeb.DashboardLive.Helpers
  import AgentsWeb.DashboardLive.SessionDataHelpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Entities.TodoList
  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Entities.Ticket
  alias Agents.Tickets.Domain.Events.TicketStageChanged
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy
  alias Agents.Tickets.Domain.Policies.TicketHierarchyPolicy
  require Logger

  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.SessionStateMachine
  alias AgentsWeb.DashboardLive.TicketSessionLinker

  @follow_up_timeout_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)
    tickets = Tickets.list_project_tickets(user.id, tasks: tasks)
    active_ticket_number = next_active_ticket_number(tickets, nil)
    queue_state_or_snapshot = load_queue_state(user.id)

    {queue_v2_enabled, queue_snapshot, queue_state} =
      case queue_state_or_snapshot do
        %QueueSnapshot{} = snapshot ->
          {true, snapshot, QueueSnapshot.to_legacy_map(snapshot)}

        queue_state when is_map(queue_state) ->
          {false, nil, queue_state}
      end

    if connected?(socket) do
      subscribe_to_active_tasks(tasks)
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:tickets")
    end

    available_images = Sessions.available_images()
    default_image = Sessions.default_image()

    sessions = merge_unassigned_active_tasks(sessions, tasks)
    sticky_warm_task_ids = derive_sticky_warm_task_ids(sessions, queue_state, MapSet.new())

    {:ok,
     socket
     |> assign(:page_title, "Sessions")
     |> assign(:full_width, true)
     |> assign(:sessions, sessions)
     |> assign(:tickets, tickets)
     |> assign(:active_ticket_number, active_ticket_number)
     |> assign(:tasks_snapshot, tasks)
     |> assign(:active_container_id, nil)
     |> assign(:current_task, nil)
     |> assign(:composing_new, false)
     |> assign(:active_session_tab, "chat")
     |> assign(:container_stats, %{})
     |> assign(:auth_refreshing, %{})
     |> assign(:events, [])
     |> assign(:available_images, available_images)
     |> assign(:selected_image, default_image)
     |> assign(:optimistic_new_sessions, [])
     |> assign(:new_task_monitors, %{})
     |> assign(:pending_ticket_starts, %{})
     |> assign(:queue_v2_enabled, queue_v2_enabled)
     |> assign(:queue_snapshot, queue_snapshot)
     |> assign(:queue_state, queue_state)
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
     |> assign(:refreshing_task_ids, MapSet.new())
     |> assign(:pending_follow_ups, %{})
     |> assign(:session_search, "")
     |> assign(:status_filter, :open)
     |> assign(:collapsed_parents, MapSet.new())
     |> assign(:fixture, nil)
     |> assign(:syncing_tickets, false)
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    socket = maybe_apply_ticket_lifecycle_fixture(socket, params)
    sessions = socket.assigns.sessions
    tasks = tasks_snapshot_or_reload(socket)
    selected_container_id = resolve_selected_container_id(params, sessions)
    current_task = resolve_current_task(params, tasks, selected_container_id)

    active_ticket_number =
      resolve_active_ticket_number(
        params,
        selected_container_id,
        sessions,
        socket.assigns.tickets,
        socket.assigns.active_ticket_number
      )

    active_tab = resolve_active_tab(params, is_integer(active_ticket_number))

    {:noreply,
     socket
     |> assign(:active_session_tab, active_tab)
     |> assign(:active_container_id, selected_container_id)
     |> assign(:active_ticket_number, active_ticket_number)
     |> assign_new(:collapsed_parents, fn -> MapSet.new() end)
     |> assign(:current_task, current_task)
     |> assign(:composing_new, selected_container_id == nil)
     |> assign(:tasks_snapshot, tasks)
     |> assign_session_state()
     |> assign(:parent_session_id, current_task && current_task.session_id)
     |> EventProcessor.maybe_load_cached_output(current_task)
     |> EventProcessor.maybe_load_pending_question(current_task)
     |> EventProcessor.maybe_load_todos(current_task)
     |> push_event("scroll_to_bottom", %{})
     |> push_event("focus_input", %{})}
  end

  @doc false
  def session_tabs do
    [
      %{id: "chat", label: "Chat"},
      %{id: "ticket", label: "Ticket"}
    ]
  end

  @impl true
  def handle_event("run_task", %{"instruction" => instruction} = params, socket) do
    instruction = String.trim(instruction)
    ticket_number = parse_ticket_number_param(params)

    ticket =
      if ticket_number,
        do: find_ticket_by_number(socket.assigns.tickets, ticket_number),
        else: nil

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      route =
        socket.assigns.current_task
        |> SessionStateMachine.state_from_task()
        |> SessionStateMachine.submission_route()

      # When the submission comes from the ticket tab for a ticket that
      # isn't associated with the current task, force a new task instead
      # of following up on an unrelated running session.
      {route, socket} =
        if route == :follow_up and is_integer(ticket_number) and
             not ticket_owns_current_task?(ticket, socket.assigns.current_task) do
          {:new_or_resume, assign(socket, :composing_new, true)}
        else
          {route, socket}
        end

      route_message_submission(route, socket, instruction, ticket_number, ticket)
    end
  end

  @impl true
  def handle_event("create_ticket", %{"body" => body}, socket) do
    body = String.trim(body)

    if body == "" do
      {:noreply, put_flash(socket, :error, "Ticket body is required")}
    else
      user = socket.assigns.current_scope.user

      case Tickets.create_ticket(body, actor_id: user.id) do
        {:ok, _ticket} ->
          {:noreply,
           socket
           |> put_flash(:info, "Ticket created")
           |> push_event("clear_input", %{})}

        {:error, reason} ->
          Logger.error("Failed to create ticket: #{inspect(reason)}")
          {:noreply, put_flash(socket, :error, "Failed to create ticket")}
      end
    end
  end

  @impl true
  def handle_event("cancel_task", _params, socket) do
    case socket.assigns.current_task do
      nil -> {:noreply, socket}
      task -> do_cancel_task(task, socket)
    end
  end

  @impl true
  def handle_event("refresh_auth_and_resume", params, socket) do
    task_id = params["task-id"] || (socket.assigns.current_task && socket.assigns.current_task.id)

    cond do
      is_nil(task_id) ->
        {:noreply, socket}

      Map.has_key?(socket.assigns.auth_refreshing, task_id) ->
        # Already refreshing this session
        {:noreply, socket}

      true ->
        user = socket.assigns.current_scope.user

        async =
          Task.async(fn -> {task_id, Sessions.refresh_auth_and_resume(task_id, user.id)} end)

        {:noreply,
         socket
         |> assign(
           :auth_refreshing,
           Map.put(socket.assigns.auth_refreshing, task_id, async.ref)
         )
         |> put_flash(:info, "Refreshing auth and restarting container...")}
    end
  end

  @impl true
  def handle_event("restart_session", _params, socket) do
    current_task = socket.assigns.current_task

    if resumable_task?(current_task) do
      # Resend the last user message from the chat history so the agent
      # picks up exactly where it left off — no extra "Continue" noise.
      instruction =
        last_user_message(socket.assigns.output_parts) ||
          current_task.instruction

      socket
      |> run_or_resume_task(instruction, nil)
      |> handle_task_result(socket)
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("refresh_all_auth", _params, socket) do
    user = socket.assigns.current_scope.user
    tasks = Sessions.list_tasks(user.id)

    refreshable =
      Enum.filter(tasks, fn t ->
        t.status == "failed" and auth_error?(t.error) and resumable_task?(t) and
          not Map.has_key?(socket.assigns.auth_refreshing, t.id)
      end)

    socket =
      Enum.reduce(refreshable, socket, fn t, acc ->
        async = Task.async(fn -> {t.id, Sessions.refresh_auth_and_resume(t.id, user.id)} end)
        assign(acc, :auth_refreshing, Map.put(acc.assigns.auth_refreshing, t.id, async.ref))
      end)

    flash_msg =
      case length(refreshable) do
        0 -> "No sessions need auth refresh"
        n -> "Refreshing auth for #{n} session(s)..."
      end

    {:noreply, put_flash(socket, :info, flash_msg)}
  end

  @impl true
  def handle_event("new_session", _params, socket) do
    {:noreply,
     socket
     |> assign(:active_container_id, nil)
     |> assign(:current_task, nil)
     |> assign(:composing_new, true)
     |> assign(:selected_image, Sessions.default_image())
     |> assign(:events, [])
     |> assign_session_state()
     |> clear_form()
     |> push_patch(to: ~p"/sessions?#{%{new: true}}")
     |> push_event("focus_input", %{})}
  end

  @impl true
  def handle_event("switch_tab", %{"tab" => tab}, socket) do
    valid_tabs = Enum.map(session_tabs(), & &1.id)
    tab = if tab in valid_tabs, do: tab, else: "chat"

    params =
      %{"tab" => tab}
      |> maybe_put_container(socket.assigns.active_container_id)
      |> maybe_put_new(socket.assigns.composing_new)

    {:noreply, push_patch(socket, to: ~p"/sessions?#{params}")}
  end

  @impl true
  def handle_event(
        "reorder_triage_tickets",
        %{"ordered_numbers" => ordered},
        socket
      ) do
    ordered_numbers =
      ordered
      |> normalize_ordered_ticket_numbers()
      |> Enum.uniq()

    # Persist positions to the database (display order: first = top = highest position)
    Tickets.reorder_triage_tickets(ordered_numbers)

    # Reload from DB to get the canonical order
    tickets = reload_tickets(socket)

    {:noreply, assign(socket, :tickets, tickets)}
  end

  @impl true
  def handle_event("send_ticket_to_top", %{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        Tickets.send_ticket_to_top(number)
        tickets = reload_tickets(socket)
        {:noreply, assign(socket, :tickets, tickets)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("send_ticket_to_bottom", %{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        Tickets.send_ticket_to_bottom(number)
        tickets = reload_tickets(socket)
        {:noreply, assign(socket, :tickets, tickets)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_concurrency_limit", %{"concurrency_limit" => limit_str}, socket) do
    user = socket.assigns.current_scope.user

    case Integer.parse(limit_str) do
      {limit, ""} when limit >= 0 and limit <= 5 ->
        Sessions.set_concurrency_limit(user.id, limit)
        # Queue state will be updated via PubSub broadcast from QueueManager
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_warm_cache_limit", %{"warm_cache_limit" => limit_str}, socket) do
    user = socket.assigns.current_scope.user

    case Integer.parse(limit_str) do
      {limit, ""} when limit >= 0 and limit <= 5 ->
        Sessions.set_warm_cache_limit(user.id, limit)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_image", %{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
  end

  @impl true
  def handle_event("session_search", %{"session_search" => query}, socket) do
    {:noreply, assign(socket, :session_search, String.trim(query))}
  end

  @impl true
  def handle_event("clear_session_search", _params, socket) do
    {:noreply, assign(socket, :session_search, "")}
  end

  @valid_status_filters %{
    "all" => :all,
    "open" => :open,
    "closed" => :closed,
    "awaiting_feedback" => :awaiting_feedback,
    "completed" => :completed,
    "cancelled" => :cancelled,
    "running" => :running,
    "queued" => :queued,
    "failed" => :failed
  }

  @impl true
  def handle_event("status_filter", %{"status" => status}, socket) do
    case Map.get(@valid_status_filters, status) do
      nil -> {:noreply, socket}
      filter -> {:noreply, assign(socket, :status_filter, filter)}
    end
  end

  @impl true
  def handle_event("select_session", %{"container-id" => container_id}, socket) do
    active_ticket_number =
      find_ticket_number_for_selected_session(
        socket.assigns.sessions,
        socket.assigns.tickets,
        container_id
      )

    {:noreply,
     socket
     |> assign(:active_ticket_number, active_ticket_number)
     |> assign(:composing_new, false)
     |> assign(:events, [])
     |> assign_session_state()
     |> clear_form()
     |> push_patch(to: ~p"/sessions?#{%{container: container_id}}")}
  end

  @impl true
  def handle_event("select_ticket", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    ticket = find_ticket_by_number(socket.assigns.tickets, number)
    container_id = ticket && ticket.associated_container_id

    # Only navigate to the associated container if it actually exists in the
    # sessions list. A stale associated_container_id (from a deleted session)
    # would otherwise fall through to the default session in handle_params,
    # causing the ticket tab to display on an unrelated session.
    session_exists =
      is_binary(container_id) and
        Enum.any?(socket.assigns.sessions, &(&1.container_id == container_id))

    if session_exists do
      {:noreply,
       socket
       |> assign(:active_ticket_number, number)
       |> assign(:composing_new, false)
       |> assign(:events, [])
       |> assign_session_state()
       |> clear_form()
       |> push_patch(to: ~p"/sessions?#{%{container: container_id, tab: "ticket"}}")}
    else
      {:noreply,
       socket
       |> assign(:active_ticket_number, number)
       |> assign(:active_container_id, nil)
       |> assign(:current_task, nil)
       |> assign(:composing_new, true)
       |> assign(:events, [])
       |> assign_session_state()
       |> clear_form()
       |> push_patch(to: ~p"/sessions?#{%{new: true, tab: "ticket"}}")
       |> push_event("focus_input", %{})}
    end
  end

  @impl true
  def handle_event("toggle_parent_collapse", %{"ticket-id" => ticket_id}, socket) do
    collapsed_parents = socket.assigns[:collapsed_parents] || MapSet.new()

    updated =
      if MapSet.member?(collapsed_parents, ticket_id) do
        MapSet.delete(collapsed_parents, ticket_id)
      else
        MapSet.put(collapsed_parents, ticket_id)
      end

    {:noreply, assign(socket, :collapsed_parents, updated)}
  end

  @impl true
  def handle_event("simulate_ticket_transition_in_progress_to_in_review", _params, socket) do
    transitioned_at = DateTime.utc_now() |> DateTime.truncate(:second)
    send(self(), {:ticket_stage_changed, 402, "in_review", transitioned_at})
    {:noreply, socket}
  end

  @impl true
  def handle_event("close_ticket", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)

    case Tickets.close_project_ticket(number) do
      :ok ->
        {:noreply, apply_ticket_closed(socket, number)}

      {:error, _reason} ->
        {:noreply,
         put_flash(socket, :error, "Failed to close ticket on GitHub. Please try again.")}
    end
  end

  @impl true
  def handle_event("sync_tickets", _params, socket) do
    lv = self()

    Task.start(fn ->
      result = Tickets.sync_tickets()
      send(lv, {:ticket_sync_finished, result})
    end)

    {:noreply, assign(socket, :syncing_tickets, true)}
  end

  @impl true
  def handle_event("start_ticket_session", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    ticket = find_ticket_by_number(socket.assigns.tickets, number)

    if is_nil(ticket) do
      {:noreply, put_flash(socket, :error, "Ticket ##{number} not found")}
    else
      context = Tickets.build_ticket_context(ticket)

      instruction =
        "pick up ticket ##{number} using the relevant skill\n\n#{context}"
        |> String.trim()

      user = socket.assigns.current_scope.user
      image = socket.assigns.selected_image || Sessions.default_image()
      client_id = Ecto.UUID.generate()
      parent = self()

      {_pid, monitor_ref} =
        spawn_monitor(fn ->
          result =
            Sessions.create_task(%{
              instruction: instruction,
              user_id: user.id,
              image: image
            })

          send(parent, {:new_task_created, client_id, result})
        end)

      # Optimistically move the ticket to the build queue immediately.
      # The ticket card renders with full ticket info (title, labels, number)
      # while the async task creation completes in the background.
      tickets =
        update_ticket_by_number(socket.assigns.tickets, number, fn t ->
          %{
            t
            | task_status: "queued",
              associated_task_id: client_id,
              session_state: "queued_cold"
          }
        end)

      {:noreply,
       socket
       |> assign(
         :new_task_monitors,
         Map.put(socket.assigns.new_task_monitors, monitor_ref, client_id)
       )
       |> assign(
         :pending_ticket_starts,
         Map.put(socket.assigns.pending_ticket_starts, client_id, number)
       )
       |> assign(:tickets, tickets)}
    end
  end

  @impl true
  def handle_event("remove_ticket_from_queue", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    ticket = find_ticket_by_number(socket.assigns.tickets, number)

    cond do
      is_nil(ticket) ->
        {:noreply, put_flash(socket, :error, "Ticket not found")}

      is_nil(ticket.associated_task_id) ->
        {:noreply, put_flash(socket, :error, "Ticket has no associated task")}

      true ->
        case Sessions.get_task(ticket.associated_task_id, socket.assigns.current_scope.user.id) do
          {:ok, task} ->
            case perform_cancel_task(task, socket) do
              {:ok, socket} ->
                # Clear the persisted FK so the ticket doesn't re-associate
                # on next page reload (Bug 1 fix).
                socket = TicketSessionLinker.unlink_and_refresh(socket, number)

                {:noreply,
                 put_flash(socket, :info, "Ticket ##{number} paused and moved to triage")}

              {:error, socket} ->
                {:noreply, socket}
            end

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to find task for ticket ##{number}")}
        end
    end
  end

  @impl true
  def handle_event("pause_session", %{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        do_cancel_task(task, socket, "Session paused")

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to find task")}
    end
  end

  @impl true
  def handle_event("delete_session", %{"container-id" => container_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_session(container_id, user.id) do
      :ok ->
        sessions = Enum.reject(socket.assigns.sessions, &(&1.container_id == container_id))

        socket =
          if socket.assigns.active_container_id == container_id,
            do:
              socket
              |> assign(:active_container_id, nil)
              |> assign(:current_task, nil)
              |> assign(:events, [])
              |> assign_session_state(),
            else: socket

        # Remove deleted tasks from the snapshot and re-enrich tickets so they
        # no longer reference the now-deleted session.
        {tasks_snapshot, tickets} =
          TicketSessionLinker.cleanup_and_refresh(
            socket.assigns[:tasks_snapshot],
            socket.assigns.tickets,
            container_id
          )

        sticky_warm_task_ids =
          derive_sticky_warm_task_ids(
            sessions,
            socket.assigns[:queue_state] || default_queue_state(),
            socket.assigns[:sticky_warm_task_ids] || MapSet.new()
          )

        {:noreply,
         socket
         |> assign(:sessions, sessions)
         |> assign(:tasks_snapshot, tasks_snapshot)
         |> assign(:tickets, tickets)
         |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
         |> put_flash(:info, "Session deleted")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to delete session")}
    end
  end

  @impl true
  def handle_event("delete_queued_task", params, socket) do
    user = socket.assigns.current_scope.user

    task_id = Map.get(params, "task-id")
    container_id = Map.get(params, "container-id")

    case resolve_queued_delete(task_id, container_id, user.id) do
      :ok ->
        socket = clear_deleted_selection(socket, task_id, container_id)

        sessions =
          Enum.reject(socket.assigns.sessions, fn session ->
            session.container_id == container_id or session.latest_task_id == task_id
          end)

        # Remove deleted tasks from snapshot and re-enrich tickets so they
        # no longer reference the now-deleted task.
        {tasks_snapshot, tickets} =
          TicketSessionLinker.cleanup_and_refresh(
            socket.assigns[:tasks_snapshot],
            socket.assigns.tickets,
            container_id
          )

        sticky_warm_task_ids =
          derive_sticky_warm_task_ids(
            sessions,
            socket.assigns[:queue_state] || default_queue_state(),
            socket.assigns[:sticky_warm_task_ids] || MapSet.new()
          )

        {:noreply,
         socket
         |> assign(:sessions, sessions)
         |> assign(:tasks_snapshot, tasks_snapshot)
         |> assign(:tickets, tickets)
         |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
         |> put_flash(:info, "Queued session removed")}

      {:error, reason} ->
        {:noreply, put_flash(socket, :error, task_error_message(reason))}
    end
  end

  @impl true
  def handle_event(
        "toggle_question_option",
        %{"question-index" => q_idx_str, "label" => label},
        socket
      ) do
    case socket.assigns.pending_question do
      nil ->
        {:noreply, socket}

      pending ->
        q_idx = String.to_integer(q_idx_str)
        multiple = Enum.at(pending.questions, q_idx)["multiple"] || false
        current = Enum.at(pending.selected, q_idx, [])

        updated =
          List.replace_at(pending.selected, q_idx, toggle_selection(current, label, multiple))

        {:noreply, assign(socket, :pending_question, %{pending | selected: updated})}
    end
  end

  @impl true
  def handle_event("update_question_form", %{"custom_answer" => custom_map}, socket) do
    case socket.assigns.pending_question do
      nil ->
        {:noreply, socket}

      pending ->
        updated =
          pending.custom_text
          |> Enum.with_index()
          |> Enum.map(fn {_old, idx} -> Map.get(custom_map, to_string(idx), "") end)

        {:noreply, assign(socket, :pending_question, %{pending | custom_text: updated})}
    end
  end

  @impl true
  def handle_event("update_question_form", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event("submit_question_answer", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {%{rejected: true} = pending, %{id: task_id}} ->
        {:noreply, submit_rejected_question(socket, pending, task_id)}

      {pending, %{id: task_id}} ->
        {:noreply, submit_active_question(socket, pending, task_id)}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("dismiss_question", _params, socket) do
    case {socket.assigns.pending_question, socket.assigns.current_task} do
      {nil, _} ->
        {:noreply, socket}

      {%{rejected: true}, _} ->
        {:noreply, assign(socket, :pending_question, nil)}

      {pending, %{id: task_id}} ->
        Sessions.reject_question(task_id, pending.request_id)
        {:noreply, assign(socket, :pending_question, %{pending | rejected: true})}

      _ ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event(
        "hydrate_optimistic_queue",
        %{"task_id" => task_id, "entries" => entries},
        socket
      )
      when is_binary(task_id) and is_list(entries) do
    current_task_id = socket.assigns.current_task && socket.assigns.current_task.id

    if current_task_id == task_id do
      hydrated =
        entries
        |> Enum.map(&normalize_hydrated_queue_entry/1)
        |> Enum.reject(&is_nil/1)

      merged = merge_queued_messages(socket.assigns.queued_messages, hydrated)

      {:noreply,
       socket
       |> assign(:queued_messages, merged)
       |> broadcast_optimistic_queue_snapshot()}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("hydrate_optimistic_queue", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_event(
        "hydrate_optimistic_new_sessions",
        %{"entries" => entries},
        socket
      )
      when is_list(entries) do
    sessions = socket.assigns.sessions

    hydrated =
      entries
      |> Enum.map(&normalize_hydrated_new_session_entry/1)
      |> Enum.reject(fn entry ->
        is_nil(entry) or stale_optimistic_entry?(entry) or
          already_has_real_session?(entry, sessions)
      end)

    {:noreply,
     socket
     |> assign(
       :optimistic_new_sessions,
       merge_optimistic_new_sessions(socket.assigns.optimistic_new_sessions, hydrated)
     )
     |> broadcast_optimistic_new_sessions_snapshot()}
  end

  @impl true
  def handle_event("hydrate_optimistic_new_sessions", _params, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:task_event, task_id, event}, socket) do
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

  @impl true
  def handle_info({:answer_question_async, task_id, request_id, answers, message}, socket) do
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

  @impl true
  def handle_info({:todo_updated, task_id, todo_items}, socket) do
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

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket) do
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

  @impl true
  def handle_info({:lifecycle_state_changed, task_id, _from_state, to_state}, socket) do
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

    tickets =
      TicketEnrichmentPolicy.enrich_all(
        socket.assigns.tickets,
        tasks_snapshot,
        &SessionLifecyclePolicy.derive/1
      )

    {:noreply,
     socket
     |> assign(:current_task, updated_current_task)
     |> assign(:sessions, sessions)
     |> assign(:tasks_snapshot, tasks_snapshot)
     |> assign(:tickets, tickets)}
  end

  @impl true
  def handle_info({:container_stats_updated, _task_id, container_id, stats}, socket) do
    {:noreply,
     assign(
       socket,
       :container_stats,
       Map.put(socket.assigns.container_stats, container_id, stats)
     )}
  end

  # Tagged async result from per-session auth refresh (success)
  @impl true
  def handle_info({ref, {task_id, {:ok, new_task}}}, socket)
      when is_reference(ref) and is_binary(task_id) do
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
  @impl true
  def handle_info({ref, {task_id, {:error, reason}}}, socket)
      when is_reference(ref) and is_binary(task_id) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> assign(:auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))
     |> put_flash(:error, "Session refresh failed: #{task_error_message(reason)}")}
  end

  # Untagged async result (from run_or_resume_task — not auth refresh)
  @impl true
  def handle_info({:new_task_created, client_id, {:ok, task}}, socket) do
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

  @impl true
  def handle_info({:new_task_created, client_id, {:error, reason}}, socket) do
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

  @impl true
  def handle_info({ref, {:ok, new_task}}, socket) when is_reference(ref) do
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

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    Process.demonitor(ref, [:flush])

    {:noreply,
     socket
     |> clear_flash()
     |> put_flash(:error, task_error_message(reason))}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket) do
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

  @impl true
  def handle_info({:queue_snapshot, user_id, %QueueSnapshot{} = snapshot}, socket)
      when user_id == socket.assigns.current_scope.user.id do
    {:noreply,
     socket
     |> assign(:queue_snapshot, snapshot)
     |> assign(:queue_state, QueueSnapshot.to_legacy_map(snapshot))}
  end

  @impl true
  def handle_info({:queue_updated, user_id, queue_state}, socket) do
    if user_id == socket.assigns.current_scope.user.id do
      sticky_warm_task_ids =
        derive_sticky_warm_task_ids(
          socket.assigns.sessions,
          queue_state,
          socket.assigns[:sticky_warm_task_ids] || MapSet.new()
        )

      tickets =
        TicketEnrichmentPolicy.enrich_all(
          socket.assigns.tickets,
          socket.assigns[:tasks_snapshot] || [],
          &SessionLifecyclePolicy.derive/1
        )

      {:noreply,
       socket
       |> assign(:queue_state, queue_state)
       |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
       |> assign(:tickets, tickets)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:tickets_synced, _tickets}, socket) do
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

  @impl true
  def handle_info({:ticket_stage_changed, ticket_id, to_stage, transitioned_at}, socket) do
    {:noreply, update_ticket_lifecycle_assigns(socket, ticket_id, to_stage, transitioned_at)}
  end

  @impl true
  def handle_info(%TicketStageChanged{} = event, socket) do
    transitioned_at = event.occurred_at || DateTime.utc_now() |> DateTime.truncate(:second)

    {:noreply,
     update_ticket_lifecycle_assigns(socket, event.ticket_id, event.to_stage, transitioned_at)}
  end

  @impl true
  def handle_info({:ticket_sync_finished, _result}, socket) do
    {:noreply, assign(socket, :syncing_tickets, false)}
  end

  @impl true
  def handle_info({:task_refreshed, task_id, {:ok, task}}, socket) do
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

  @impl true
  def handle_info({:task_refreshed, task_id, _}, socket) do
    {:noreply,
     assign(
       socket,
       :refreshing_task_ids,
       MapSet.delete(socket.assigns[:refreshing_task_ids] || MapSet.new(), task_id)
     )}
  end

  @impl true
  def handle_info(
        {:dispatch_follow_up_message, task_id, instruction, correlation_key, queued_at},
        socket
      ) do
    caller = self()
    timeout_ref = make_ref()

    Task.start(fn ->
      try do
        result =
          Sessions.send_message(
            task_id,
            instruction,
            correlation_key: correlation_key,
            command_type: "follow_up_message",
            sent_at: DateTime.to_iso8601(queued_at)
          )

        send(caller, {:follow_up_send_result, correlation_key, result})
      rescue
        error ->
          send(caller, {:follow_up_send_result, correlation_key, {:error, error}})
      end
    end)

    Process.send_after(
      self(),
      {:follow_up_timeout, correlation_key, timeout_ref},
      @follow_up_timeout_ms
    )

    pending =
      Map.put(socket.assigns.pending_follow_ups, correlation_key, %{
        ref: timeout_ref,
        dispatched_at: DateTime.utc_now()
      })

    {:noreply, assign(socket, :pending_follow_ups, pending)}
  end

  @impl true
  def handle_info({:follow_up_send_result, correlation_key, :ok}, socket) do
    {:noreply,
     assign(
       socket,
       :pending_follow_ups,
       Map.delete(socket.assigns.pending_follow_ups, correlation_key)
     )}
  end

  @impl true
  def handle_info({:follow_up_send_result, correlation_key, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :pending_follow_ups,
       Map.delete(socket.assigns.pending_follow_ups, correlation_key)
     )
     |> assign(
       :queued_messages,
       SessionStateMachine.mark_queued_message_status(
         socket.assigns.queued_messages,
         correlation_key,
         "rolled_back"
       )
     )
     |> broadcast_optimistic_queue_snapshot()
     |> put_flash(:error, "Failed to send message")}
  end

  @impl true
  def handle_info({:follow_up_timeout, correlation_key, timeout_ref}, socket) do
    case Map.get(socket.assigns.pending_follow_ups, correlation_key) do
      %{ref: ^timeout_ref} ->
        Logger.warning("Follow-up dispatch timed out for correlation_key=#{correlation_key}")

        {:noreply,
         socket
         |> assign(
           :pending_follow_ups,
           Map.delete(socket.assigns.pending_follow_ups, correlation_key)
         )
         |> assign(
           :queued_messages,
           SessionStateMachine.mark_queued_message_status(
             socket.assigns.queued_messages,
             correlation_key,
             "timed_out"
           )
         )
         |> broadcast_optimistic_queue_snapshot()}

      _ ->
        # Already resolved (success or error arrived before timeout) — ignore
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  def ticket_data_id(ticket) do
    Map.get(ticket, :external_id) || "ticket-#{ticket.number}"
  end
end
