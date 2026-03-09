defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.SessionsLive.Components.SessionComponents
  import AgentsWeb.SessionsLive.Components.QueueLaneComponents
  import AgentsWeb.SessionsLive.Helpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.Ticket
  alias Agents.Sessions.Domain.Policies.TicketEnrichmentPolicy
  alias Agents.Sessions.Domain.Policies.TicketHierarchyPolicy
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Sessions.Domain.Entities.TodoList
  require Logger

  alias AgentsWeb.SessionsLive.EventProcessor
  alias AgentsWeb.SessionsLive.SessionStateMachine

  @follow_up_timeout_ms 30_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)
    tickets = Sessions.list_project_tickets(user.id, tasks: tasks)
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
     |> assign(:queue_v2_enabled, queue_v2_enabled)
     |> assign(:queue_snapshot, queue_snapshot)
     |> assign(:queue_state, queue_state)
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
     |> assign(:refreshing_task_ids, MapSet.new())
     |> assign(:pending_follow_ups, %{})
     |> assign(:session_search, "")
     |> assign(:status_filter, :open)
     |> assign(:collapsed_parents, MapSet.new())
     |> assign(:syncing_tickets, false)
     |> assign_session_state()
     |> assign(:form, to_form(%{"instruction" => ""}))}
  end

  @impl true
  def handle_params(params, _url, socket) do
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

  defp resolve_active_tab(params, has_ticket_tab?) do
    tab = params["tab"] || "chat"
    valid_tabs = Enum.map(if(has_ticket_tab?, do: session_tabs(), else: [%{id: "chat"}]), & &1.id)
    if tab in valid_tabs, do: tab, else: "chat"
  end

  defp resolve_active_ticket_number(
         %{"new" => "true"},
         _selected_container_id,
         _sessions,
         _tickets,
         current
       ) do
    current
  end

  defp resolve_active_ticket_number(_params, selected_container_id, sessions, tickets, _current)
       when is_binary(selected_container_id) and selected_container_id != "" do
    find_ticket_number_for_selected_session(sessions, tickets, selected_container_id)
  end

  defp resolve_active_ticket_number(
         _params,
         _selected_container_id,
         _sessions,
         _tickets,
         current
       ),
       do: current

  defp tasks_snapshot_or_reload(socket) do
    socket.assigns[:tasks_snapshot] || Sessions.list_tasks(socket.assigns.current_scope.user.id)
  end

  defp resolve_selected_container_id(%{"new" => "true"}, _sessions), do: nil

  defp resolve_selected_container_id(%{"container" => container_id}, sessions)
       when is_binary(container_id) do
    if Enum.any?(sessions, &(&1.container_id == container_id)) do
      container_id
    else
      default_container_id(sessions)
    end
  end

  defp resolve_selected_container_id(_params, sessions), do: default_container_id(sessions)

  defp default_container_id([first | _]), do: first.container_id
  defp default_container_id([]), do: nil

  defp resolve_current_task(%{"new" => "true"}, _tasks, _selected_container_id), do: nil

  defp resolve_current_task(_params, tasks, selected_container_id) do
    find_current_task(tasks, selected_container_id)
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

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      socket.assigns.current_task
      |> SessionStateMachine.state_from_task()
      |> SessionStateMachine.submission_route()
      |> route_message_submission(socket, instruction, ticket_number)
    end
  end

  @impl true
  def handle_event("run_new_task", %{"instruction" => instruction}, socket) do
    instruction = String.trim(instruction)

    if instruction == "" do
      {:noreply, put_flash(socket, :error, "Instruction is required")}
    else
      user = socket.assigns.current_scope.user
      image = socket.assigns.selected_image || Sessions.default_image()
      client_id = Ecto.UUID.generate()
      queued_at = DateTime.utc_now()

      optimistic_entry = %{
        id: client_id,
        instruction: instruction,
        image: image,
        status: "queued",
        queued_at: queued_at
      }

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

      {:noreply,
       socket
       |> assign(
         :new_task_monitors,
         Map.put(socket.assigns.new_task_monitors, monitor_ref, client_id)
       )
       |> assign(
         :optimistic_new_sessions,
         merge_optimistic_new_sessions(socket.assigns.optimistic_new_sessions, [optimistic_entry])
       )
       |> broadcast_optimistic_new_sessions_snapshot()}
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
    Sessions.reorder_triage_tickets(ordered_numbers)

    # Reload from DB to get the canonical order
    tickets = reload_tickets(socket)

    {:noreply, assign(socket, :tickets, tickets)}
  end

  @impl true
  def handle_event("send_ticket_to_top", %{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        Sessions.send_ticket_to_top(number)
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
        Sessions.send_ticket_to_bottom(number)
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
      {limit, ""} when limit >= 1 and limit <= 5 ->
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

    if is_binary(container_id) do
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
  def handle_event("close_ticket", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    user = socket.assigns.current_scope.user

    # Find the ticket to get its associated session container_id
    ticket = find_ticket_by_number(socket.assigns.tickets, number)
    container_id = ticket && ticket.associated_container_id

    # Destroy the associated session if it exists
    if is_binary(container_id) do
      Sessions.delete_session(container_id, user.id)
    end

    # Optimistically mark the ticket as closed so it moves out of the Open filter
    tickets =
      map_ticket_tree(socket.assigns.tickets, fn t ->
        if t.number == number, do: %{t | state: "closed"}, else: t
      end)

    # Remove the associated session from the sessions list
    sessions =
      if is_binary(container_id) do
        Enum.reject(socket.assigns.sessions, &(&1.container_id == container_id))
      else
        socket.assigns.sessions
      end

    active_ticket_number =
      if socket.assigns.active_ticket_number == number,
        do: nil,
        else: socket.assigns.active_ticket_number

    # Switch back to chat tab if we just closed the viewed ticket
    tab =
      if socket.assigns.active_ticket_number == number and
           socket.assigns.active_session_tab == "ticket",
         do: "chat",
         else: socket.assigns.active_session_tab

    # Clear active selection if we just destroyed the viewed session
    socket =
      if socket.assigns.active_container_id == container_id do
        socket
        |> assign(:active_container_id, nil)
        |> assign(:current_task, nil)
        |> assign(:events, [])
        |> assign_session_state()
      else
        socket
      end

    Sessions.close_project_ticket(number)

    {:noreply,
     socket
     |> assign(:tickets, tickets)
     |> assign(:sessions, sessions)
     |> assign(:active_ticket_number, active_ticket_number)
     |> assign(:active_session_tab, tab)}
  end

  @impl true
  def handle_event("sync_tickets", _params, socket) do
    lv = self()

    Task.start(fn ->
      result = Sessions.sync_tickets()
      send(lv, {:ticket_sync_finished, result})
    end)

    {:noreply, assign(socket, :syncing_tickets, true)}
  end

  @impl true
  def handle_event("start_ticket_session", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    instruction = "pick up ticket ##{number} using the relevant skill"

    # Delegate to the existing run_new_task handler
    handle_event("run_new_task", %{"instruction" => instruction}, socket)
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
            do_cancel_task(task, socket, "Ticket ##{number} paused and moved to triage")

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

        sticky_warm_task_ids =
          derive_sticky_warm_task_ids(
            sessions,
            socket.assigns[:queue_state] || default_queue_state(),
            socket.assigns[:sticky_warm_task_ids] || MapSet.new()
          )

        {:noreply,
         socket
         |> assign(:sessions, sessions)
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

        sticky_warm_task_ids =
          derive_sticky_warm_task_ids(
            sessions,
            socket.assigns[:queue_state] || default_queue_state(),
            socket.assigns[:sticky_warm_task_ids] || MapSet.new()
          )

        {:noreply,
         socket
         |> assign(:sessions, sessions)
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
    tickets = TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)

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

    tickets = TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)

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
       TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)
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

    # Persist ticket-task association when a new task references a ticket
    maybe_link_ticket_to_task(task)

    sessions = upsert_session_from_task(socket.assigns.sessions, task)

    sticky_warm_task_ids =
      derive_sticky_warm_task_ids(
        sessions,
        socket.assigns[:queue_state] || default_queue_state(),
        socket.assigns[:sticky_warm_task_ids] || MapSet.new()
      )

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], task)

    # Reload tickets from DB so the persisted task_id is picked up
    tickets =
      Sessions.list_project_tickets(user.id, tasks: tasks_snapshot)

    {:noreply,
     socket
     |> clear_new_task_monitor(client_id)
     |> assign(
       :optimistic_new_sessions,
       remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
     )
     |> broadcast_optimistic_new_sessions_snapshot()
     |> assign(:sessions, sessions)
     |> assign(:tasks_snapshot, tasks_snapshot)
     |> assign(:tickets, tickets)
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)}
  end

  @impl true
  def handle_info({:new_task_created, client_id, {:error, reason}}, socket) do
    {:noreply,
     socket
     |> clear_new_task_monitor(client_id)
     |> assign(
       :optimistic_new_sessions,
       remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
     )
     |> broadcast_optimistic_new_sessions_snapshot()
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
       TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)
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
        {:noreply,
         socket
         |> assign(:new_task_monitors, monitors)
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
          socket.assigns[:tasks_snapshot] || []
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
    user = socket.assigns.current_scope.user

    ticket_opts =
      case socket.assigns[:tasks_snapshot] do
        tasks when is_list(tasks) and tasks != [] -> [tasks: tasks]
        _ -> []
      end

    tickets = Sessions.list_project_tickets(user.id, ticket_opts)

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

    {:noreply,
     socket |> assign(:tickets, tickets) |> assign(:active_ticket_number, active_ticket_number)}
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
       TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)
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

  defp delete_queued_task_by_id(task_id, user_id) do
    case Sessions.get_task(task_id, user_id) do
      {:ok, task} when is_binary(task.container_id) and task.container_id != "" ->
        Sessions.delete_session(task.container_id, user_id)

      {:ok, _task} ->
        Sessions.delete_task(task_id, user_id)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_queued_delete(task_id, container_id, user_id) do
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

  defp clear_deleted_selection(socket, task_id, container_id) do
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

  defp maybe_put_container(params, container_id)
       when is_binary(container_id) and container_id != "" do
    Map.put(params, "container", container_id)
  end

  defp maybe_put_container(params, _container_id), do: params

  defp maybe_put_new(params, true), do: Map.put(params, "new", true)
  defp maybe_put_new(params, _), do: params

  defp assign_session_state(socket) do
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
  defp clear_form(socket) do
    socket
    |> assign(:form, to_form(%{"instruction" => ""}))
    |> push_event("clear_input", %{})
  end

  # Pre-fills the instruction textarea via both LiveView form state and a push event
  # to the hook (necessary because phx-update="ignore" prevents server assigns from
  # reaching the DOM).
  defp prefill_form(socket, text) do
    socket
    |> assign(:form, to_form(%{"instruction" => text}))
    |> push_event("restore_draft", %{text: text})
  end

  defp route_message_submission(:follow_up, socket, instruction, _ticket_number) do
    send_message_to_running_task(socket, instruction)
  end

  defp route_message_submission(:new_or_resume, socket, instruction, ticket_number) do
    socket =
      if resumable_task?(socket.assigns.current_task) do
        append_optimistic_user_message(socket, instruction)
      else
        socket
      end

    socket
    |> run_or_resume_task(instruction, ticket_number)
    |> handle_task_result(socket)
  end

  defp route_message_submission(:blocked, socket, _instruction, _ticket_number) do
    {:noreply, put_flash(socket, :error, "Cannot submit message in current state")}
  end

  defp send_message_to_running_task(socket, instruction) do
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

  defp normalize_hydrated_queue_entry(entry) when is_map(entry) do
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

  defp normalize_hydrated_queue_entry(_), do: nil

  defp parse_hydrated_datetime(nil), do: DateTime.utc_now()

  defp parse_hydrated_datetime(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, dt, _offset} -> dt
      _ -> DateTime.utc_now()
    end
  end

  defp parse_hydrated_datetime(_), do: DateTime.utc_now()

  defp normalize_hydrated_new_session_entry(entry) when is_map(entry) do
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

  defp normalize_hydrated_new_session_entry(_), do: nil

  defp merge_optimistic_new_sessions(existing, incoming) do
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

  defp remove_optimistic_new_session(entries, client_id) do
    Enum.reject(entries, &(&1.id == client_id))
  end

  # An optimistic entry is stale if it was queued more than 2 minutes ago.
  # At that point the backend has either succeeded (real session exists) or
  # failed (the DOWN handler should have cleaned up).
  @optimistic_stale_seconds 120
  defp stale_optimistic_entry?(%{queued_at: %DateTime{} = queued_at}) do
    DateTime.diff(DateTime.utc_now(), queued_at, :second) > @optimistic_stale_seconds
  end

  defp stale_optimistic_entry?(_), do: true

  # An optimistic entry already has a real session if any existing session's
  # title matches the entry's instruction text.
  defp already_has_real_session?(%{instruction: instruction}, sessions)
       when is_binary(instruction) do
    trimmed = String.trim(instruction)
    Enum.any?(sessions, fn session -> String.trim(session.title || "") == trimmed end)
  end

  defp already_has_real_session?(_, _), do: false

  defp normalize_ordered_ticket_numbers(values) when is_list(values) do
    values
    |> Enum.map(&Integer.parse(to_string(&1)))
    |> Enum.filter(&match?({_, ""}, &1))
    |> Enum.map(fn {n, _} -> n end)
  end

  defp normalize_ordered_ticket_numbers(_), do: []

  defp merge_queued_messages(existing, incoming) do
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

  defp maybe_sync_optimistic_queue_snapshot(socket, previous_queue) do
    current_queue = Map.get(socket.assigns, :queued_messages, [])

    if previous_queue != current_queue do
      broadcast_optimistic_queue_snapshot(socket)
    else
      socket
    end
  end

  defp broadcast_optimistic_queue_snapshot(socket) do
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

  defp clear_optimistic_queue_snapshot(socket, task_id) when is_binary(task_id) do
    push_event(socket, "optimistic_queue_clear", %{
      user_id: socket.assigns.current_scope.user.id,
      task_id: task_id
    })
  end

  defp clear_optimistic_queue_snapshot(socket, _task_id), do: socket

  defp clear_new_task_monitor(socket, client_id) do
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

  defp maybe_flash_new_task_down(socket, :normal), do: socket

  defp maybe_flash_new_task_down(socket, reason) do
    put_flash(socket, :error, "Session creation failed: #{inspect(reason)}")
  end

  defp broadcast_optimistic_new_sessions_snapshot(socket) do
    payload = %{
      user_id: socket.assigns.current_scope.user.id,
      entries: serialize_optimistic_new_sessions(socket.assigns.optimistic_new_sessions)
    }

    push_event(socket, "optimistic_new_sessions_set", payload)
  end

  defp serialize_optimistic_new_sessions(entries) do
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

  defp serialize_queued_messages(messages) do
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

  defp serialize_queued_datetime(%DateTime{} = dt), do: DateTime.to_iso8601(dt)
  defp serialize_queued_datetime(_), do: DateTime.utc_now() |> DateTime.to_iso8601()

  defp append_optimistic_user_message(socket, message) do
    append_optimistic_part(socket, message, :user_pending)
  end

  defp append_answer_submitted_message(socket, message) do
    append_optimistic_part(socket, message, :answer_submitted)
  end

  defp append_optimistic_part(socket, message, tag) do
    trimmed = String.trim(message)
    optimistic_id = "optimistic-#{System.unique_integer([:positive])}"
    updated = socket.assigns.optimistic_user_messages ++ [trimmed]
    parts = socket.assigns.output_parts ++ [{tag, optimistic_id, trimmed}]

    socket
    |> assign(:optimistic_user_messages, updated)
    |> assign(:output_parts, parts)
  end

  defp remove_answer_submitted_part(socket, message) do
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

  defp toggle_selection(current, label, true = _multiple) do
    if label in current, do: List.delete(current, label), else: current ++ [label]
  end

  defp toggle_selection(current, label, false = _single) do
    if label in current, do: [], else: [label]
  end

  defp build_question_answers(pending) do
    Enum.zip(pending.selected, pending.custom_text)
    |> Enum.map(fn {selected, custom} ->
      custom_trimmed = String.trim(custom)
      if custom_trimmed != "", do: selected ++ [custom_trimmed], else: selected
    end)
  end

  defp format_question_answer_as_message(pending, answers) do
    Enum.zip(pending.questions, answers)
    |> Enum.map_join("\n", fn {question, answer_list} ->
      header = question["header"] || "Question"
      "Re: #{header} — #{Enum.join(answer_list, ", ")}"
    end)
  end

  defp submit_rejected_question(socket, pending, task_id) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    Sessions.send_message(task_id, message)
    |> handle_question_result_basic(socket, pending, "Failed to send message — please try again")
  end

  defp submit_active_question(socket, pending, task_id) do
    answers = build_question_answers(pending)
    message = format_question_answer_as_message(pending, answers)

    send(self(), {:answer_question_async, task_id, pending.request_id, answers, message})

    socket
    |> append_answer_submitted_message(message)
    |> assign(:pending_question, nil)
  end

  defp handle_question_result_basic(:ok, socket, _pending, _error_msg) do
    assign(socket, :pending_question, nil)
  end

  defp handle_question_result_basic({:error, :task_not_running}, socket, pending, _error_msg) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    socket
    |> assign(:pending_question, nil)
    |> prefill_form(message)
    |> put_flash(:info, "Session ended. Your answer is in the input — submit to resume.")
  end

  defp handle_question_result_basic({:error, _}, socket, _pending, error_msg) do
    socket |> assign(:pending_question, nil) |> put_flash(:error, error_msg)
  end

  defp run_or_resume_task(socket, instruction, ticket_number) do
    user = socket.assigns.current_scope.user
    current_task = socket.assigns.current_task

    if socket.assigns.composing_new || is_nil(current_task) do
      instruction = ensure_ticket_reference(instruction, ticket_number)

      Sessions.create_task(%{
        instruction: instruction,
        user_id: user.id,
        image: socket.assigns.selected_image
      })
    else
      Sessions.resume_task(current_task.id, %{instruction: instruction, user_id: user.id})
    end
  end

  defp handle_task_result({:ok, task}, socket) do
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

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], task)

    {:noreply,
     socket
     |> assign(:sessions, sessions)
     |> assign(:tasks_snapshot, tasks_snapshot)
     |> assign(
       :tickets,
       TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)
     )
     |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
     |> push_event("scroll_to_bottom", %{})
     |> push_event("focus_input", %{})}
  end

  defp handle_task_result({:error, reason}, socket) do
    {:noreply, put_flash(socket, :error, task_error_message(reason))}
  end

  defp do_cancel_task(task, socket, flash_message \\ "Task cancelled") do
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

        {:noreply,
         socket
         |> assign(:current_task, updated)
         |> assign(:parent_session_id, updated.session_id)
         |> assign(:sessions, sessions)
         |> assign(:tasks_snapshot, tasks_snapshot)
         |> assign(
           :tickets,
           TicketEnrichmentPolicy.enrich_all(socket.assigns.tickets, tasks_snapshot)
         )
         |> assign(:sticky_warm_task_ids, sticky_warm_task_ids)
         |> push_event("restore_draft", %{text: instruction})
         |> put_flash(:info, flash_message)}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  defp fetch_cancelled_task(task, user_id) do
    case Sessions.get_task(task.id, user_id) do
      {:ok, t} -> t
      _ -> Map.put(task, :status, "cancelled")
    end
  end

  # Restore the most recent user message (not the original instruction).
  # For tasks that ran, decode their output to find follow-up messages.
  # Fall back to the original instruction for queued tasks with no output.
  defp recover_instruction(updated_task, original_task) do
    case Map.get(updated_task, :output) do
      output when is_binary(output) and output != "" ->
        output
        |> EventProcessor.decode_cached_output()
        |> last_user_message()

      _ ->
        nil
    end || Map.get(updated_task, :instruction) || Map.get(original_task, :instruction, "")
  end

  defp resolve_changed_task(true, updated_current_task, _task_id, _status, _socket),
    do: updated_current_task

  defp resolve_changed_task(false, _updated_current_task, task_id, status, socket) do
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
  defp apply_status_change_to_ui(socket, false, _status, task_id),
    do: clear_optimistic_queue_snapshot(socket, task_id)

  defp apply_status_change_to_ui(socket, true, status, task_id)
       when status in ["completed", "failed"] do
    socket
    |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
    |> assign(:pending_question, nil)
    |> assign(:queued_messages, [])
    |> clear_optimistic_queue_snapshot(task_id)
  end

  defp apply_status_change_to_ui(socket, true, "cancelled", task_id) do
    socket
    |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
    |> assign(:pending_question, nil)
    |> clear_optimistic_queue_snapshot(task_id)
  end

  defp apply_status_change_to_ui(socket, true, _status, _task_id), do: socket

  defp maybe_sync_status_from_session_event(
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

  defp maybe_sync_status_from_session_event(socket, _event, _task_id), do: socket

  defp request_task_refresh(socket, task_id) when is_binary(task_id) do
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

  defp request_task_refresh(socket, _task_id), do: socket

  defp derive_sticky_warm_task_ids(sessions, queue_state, previous_sticky) do
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

  defp has_real_container?(%{container_id: container_id}) when is_binary(container_id) do
    container_id != "" and not String.starts_with?(container_id, "task:")
  end

  defp has_real_container?(_), do: false

  # Reload tickets from the database with enrichment from the current tasks snapshot.
  defp reload_tickets(socket) do
    user = socket.assigns.current_scope.user

    ticket_opts =
      case socket.assigns[:tasks_snapshot] do
        tasks when is_list(tasks) and tasks != [] -> [tasks: tasks]
        _ -> []
      end

    Sessions.list_project_tickets(user.id, ticket_opts)
  end

  defp map_ticket_tree(tickets, fun) when is_list(tickets) do
    Enum.map(tickets, fn ticket ->
      updated = fun.(ticket)
      %{updated | sub_tickets: map_ticket_tree(updated.sub_tickets || [], fun)}
    end)
  end

  defp all_tickets(tickets) when is_list(tickets) do
    Enum.flat_map(tickets, fn ticket -> [ticket | all_tickets(ticket.sub_tickets || [])] end)
  end

  defp find_ticket_by_number(tickets, number) when is_integer(number) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.number == number))
  end

  defp find_ticket_by_number(_tickets, _number), do: nil

  defp find_parent_ticket(_tickets, %{parent_ticket_id: nil}), do: nil

  defp find_parent_ticket(tickets, %{parent_ticket_id: parent_id}) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.id == parent_id))
  end

  defp upsert_task_snapshot(tasks, nil), do: tasks

  defp upsert_task_snapshot(tasks, task) when is_list(tasks) do
    {matches, rest} = Enum.split_with(tasks, &(&1.id == task.id))

    merged =
      case matches do
        [existing | _] -> Map.merge(existing, task)
        [] -> task
      end

    [merged | rest]
  end

  defp upsert_task_snapshot(_tasks, task), do: [task]

  defp update_task_lifecycle_state(tasks, _task_id, _lifecycle_state) when not is_list(tasks),
    do: tasks

  defp update_task_lifecycle_state(tasks, task_id, lifecycle_state) do
    Enum.map(tasks, fn
      %{id: ^task_id} = task -> Map.put(task, :lifecycle_state, lifecycle_state)
      task -> task
    end)
  end

  defp update_session_lifecycle_state(sessions, _task_id, _lifecycle_state)
       when not is_list(sessions),
       do: sessions

  defp update_session_lifecycle_state(sessions, task_id, lifecycle_state) do
    Enum.map(sessions, fn
      %{latest_task_id: ^task_id} = session -> Map.put(session, :lifecycle_state, lifecycle_state)
      session -> session
    end)
  end

  defp lifecycle_state_to_string(state) when is_atom(state), do: Atom.to_string(state)
  defp lifecycle_state_to_string(state) when is_binary(state), do: state
  defp lifecycle_state_to_string(_state), do: "idle"

  defp lifecycle_state_for_task_status(task, status) do
    task
    |> Map.put(:status, status)
    |> Map.put(:lifecycle_state, nil)
    |> SessionStateMachine.state_from_task()
    |> lifecycle_state_to_string()
  end

  defp find_ticket_number_for_container(tickets, container_id) do
    case Enum.find(all_tickets(tickets), &(&1.associated_container_id == container_id)) do
      %{number: number} -> number
      _ -> nil
    end
  end

  defp find_ticket_number_for_selected_session(sessions, tickets, container_id) do
    case find_ticket_number_for_container(tickets, container_id) do
      number when is_integer(number) ->
        number

      _ ->
        extract_ticket_number_from_session(sessions, tickets, container_id)
    end
  end

  defp extract_ticket_number_from_session(sessions, tickets, container_id) do
    session = Enum.find(sessions, &(&1.container_id == container_id))
    title = is_map(session) && Map.get(session, :title)

    with title when is_binary(title) <- title,
         number when is_integer(number) and number > 0 <-
           Sessions.extract_ticket_number(title),
         true <- Enum.any?(all_tickets(tickets), &(&1.number == number)) do
      number
    else
      _ -> nil
    end
  end

  defp next_active_ticket_number([], _current), do: nil

  defp next_active_ticket_number(tickets, current) do
    flattened_tickets = all_tickets(tickets)

    case Enum.find(flattened_tickets, &(&1.number == current)) do
      %{number: number} -> number
      _ -> flattened_tickets |> List.first() |> then(&(&1 && &1.number))
    end
  end

  defp merge_unassigned_active_tasks(sessions, tasks) do
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

  defp sort_sessions_for_sidebar(sessions) do
    Enum.sort_by(sessions, fn session ->
      {running_session?(session), -latest_at_unix(session)}
    end)
  end

  defp running_session?(%{latest_status: status}) do
    status in ["pending", "starting", "running", "queued", "awaiting_feedback"]
  end

  defp running_session?(_), do: false

  defp latest_at_unix(%{latest_at: %DateTime{} = dt}), do: DateTime.to_unix(dt, :microsecond)

  defp latest_at_unix(%{latest_at: %NaiveDateTime{} = dt}),
    do: NaiveDateTime.to_gregorian_seconds(dt)

  defp latest_at_unix(_), do: 0

  defp load_queue_state(user_id) do
    Sessions.get_queue_state(user_id)
  catch
    :exit, _reason -> default_queue_state()
  end

  defp default_queue_state do
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

  defp subscribe_to_active_tasks(tasks) do
    tasks
    |> Enum.filter(&active_task?/1)
    |> Enum.each(&Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{&1.id}"))
  end

  defp update_session_todo_items(sessions, container_id, todo_maps) do
    Enum.map(sessions, fn
      %{container_id: ^container_id} = session ->
        Map.put(session, :todo_items, %{"items" => todo_maps})

      session ->
        session
    end)
  end

  defp upsert_session_from_task(sessions, task) do
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
  defp drop_default_fields(session_update, task) do
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

  defp build_session_from_task(task, task_id, task_container_id) do
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

  defp derive_container_id(cid, _task_id) when is_binary(cid) and cid != "", do: cid
  defp derive_container_id(_cid, task_id) when is_binary(task_id), do: "task:" <> task_id
  defp derive_container_id(_cid, _task_id), do: "task:unknown"

  defp split_matching_sessions(sessions, task_id, task_container_id) do
    Enum.split_with(sessions, fn session ->
      matches_container?(session, task_container_id) or session.latest_task_id == task_id
    end)
  end

  defp matches_container?(session, cid) when is_binary(cid) and cid != "",
    do: session.container_id == cid

  defp matches_container?(_session, _cid), do: false

  defp hydrate_task_for_session(task, user_id) when is_map(task) do
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

  defp hydrate_task_for_session(task, _user_id), do: task

  defp resolve_new_task_ack_task(task, user_id, optimistic_entry) do
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

  defp find_task_by_instruction(user_id, instruction) do
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

  defp parse_ticket_number_param(%{"ticket_number" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> nil
    end
  end

  defp parse_ticket_number_param(_), do: nil

  defp ensure_ticket_reference(instruction, nil), do: instruction

  defp ensure_ticket_reference(instruction, ticket_number) do
    if Sessions.extract_ticket_number(instruction) do
      instruction
    else
      "##{ticket_number} #{instruction}"
    end
  end

  defp maybe_link_ticket_to_task(task) do
    instruction = Map.get(task, :instruction, "")

    case Sessions.extract_ticket_number(instruction) do
      nil -> :ok
      ticket_number -> Sessions.link_ticket_to_task(ticket_number, task.id)
    end
  rescue
    _ -> :ok
  end
end
