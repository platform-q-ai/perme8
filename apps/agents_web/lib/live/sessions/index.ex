defmodule AgentsWeb.SessionsLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.SessionsLive.Components.SessionComponents
  import AgentsWeb.SessionsLive.Helpers

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.TodoList
  alias AgentsWeb.SessionsLive.EventProcessor

  @stats_interval_ms 5_000
  @duration_tick_ms 1_000

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)
    tickets = Sessions.list_project_tickets(user.id, tasks: tasks)
    active_ticket_number = next_active_ticket_number(tickets, nil)

    if connected?(socket) do
      subscribe_to_active_tasks(tasks)
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:tickets")
      schedule_stats_poll()
      schedule_duration_tick()
    end

    available_images = Sessions.available_images()
    default_image = Sessions.default_image()

    sessions = merge_unassigned_active_tasks(sessions, tasks)

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
     |> assign(:sidebar_list_tab, "sessions")
     |> assign(:container_stats, %{})
     |> assign(:duration_now, DateTime.utc_now())
     |> assign(:auth_refreshing, %{})
     |> assign(:events, [])
     |> assign(:available_images, available_images)
     |> assign(:selected_image, default_image)
     |> assign(:optimistic_new_sessions, [])
     |> assign(:new_task_monitors, %{})
     |> assign(:queue_state, load_queue_state(user.id))
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
     |> assign(:current_task, current_task)
     |> assign(:composing_new, selected_container_id == nil)
     |> assign(:tasks_snapshot, nil)
     |> assign(:confirmed_user_messages, [])
     |> assign(:optimistic_user_messages, [])
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

    cond do
      instruction == "" ->
        {:noreply, put_flash(socket, :error, "Instruction is required")}

      task_running?(socket.assigns.current_task) ->
        send_message_to_running_task(socket, instruction)

      true ->
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
     |> assign(:form, to_form(%{"instruction" => ""}))
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
  def handle_event("switch_sidebar_list_tab", %{"tab" => tab}, socket) do
    tab = if tab in ["sessions", "tickets"], do: tab, else: "sessions"
    {:noreply, assign(socket, :sidebar_list_tab, tab)}
  end

  @impl true
  def handle_event(
        "reorder_tickets",
        %{"moved_number" => moved, "ordered_numbers" => ordered} = params,
        socket
      ) do
    target_status = Map.get(params, "target_status")

    with {moved_number, ""} <- Integer.parse(to_string(moved)),
         ordered_numbers <- normalize_ordered_ticket_numbers(ordered) do
      optimistic_socket =
        assign(
          socket,
          :tickets,
          apply_local_ticket_reorder(
            socket.assigns.tickets,
            moved_number,
            target_status,
            ordered_numbers
          )
        )

      case Sessions.reorder_project_ticket(moved_number, target_status, ordered_numbers) do
        :ok ->
          user = socket.assigns.current_scope.user
          {:noreply, reload_all(optimistic_socket, user.id)}

        {:error, reason} ->
          {:noreply,
           put_flash(
             optimistic_socket,
             :error,
             "Ticket moved locally, but GitHub sync failed: #{inspect(reason)}"
           )}
      end
    else
      _ -> {:noreply, put_flash(socket, :error, "Failed to reorder ticket")}
    end
  end

  @impl true
  def handle_event("switch_sidebar_list_tab", %{"tab" => tab}, socket) do
    tab = if tab in ["sessions", "tickets"], do: tab, else: "sessions"
    {:noreply, assign(socket, :sidebar_list_tab, tab)}
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
     |> assign(:form, to_form(%{"instruction" => ""}))
     |> push_patch(to: ~p"/sessions?#{%{container: container_id}}")}
  end

  @impl true
  def handle_event("select_ticket", %{"number" => number_str}, socket) do
    number = String.to_integer(number_str)
    ticket = Enum.find(socket.assigns.tickets, &(&1.number == number))
    container_id = ticket && ticket.associated_container_id

    if is_binary(container_id) do
      {:noreply,
       socket
       |> assign(:active_ticket_number, number)
       |> assign(:composing_new, false)
       |> assign(:events, [])
       |> assign_session_state()
       |> assign(:form, to_form(%{"instruction" => ""}))
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
       |> assign(:form, to_form(%{"instruction" => ""}))
       |> push_patch(to: ~p"/sessions?#{%{new: true, tab: "ticket"}}")
       |> push_event("focus_input", %{})}
    end
  end

  @impl true
  def handle_event("delete_session", %{"container-id" => container_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.delete_session(container_id, user.id) do
      :ok ->
        socket =
          if socket.assigns.active_container_id == container_id,
            do:
              socket
              |> assign(:active_container_id, nil)
              |> assign(:current_task, nil)
              |> assign(:events, [])
              |> assign_session_state(),
            else: socket

        {:noreply, socket |> reload_all(user.id) |> put_flash(:info, "Session deleted")}

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

        {:noreply,
         socket
         |> reload_all(user.id)
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
    hydrated =
      entries
      |> Enum.map(&normalize_hydrated_new_session_entry/1)
      |> Enum.reject(&is_nil/1)

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
         |> assign(:form, to_form(%{"instruction" => message}))
         |> put_flash(:info, "Session ended. Your answer is in the input — submit to resume.")}

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to submit answer — please try again")}
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
    updated_task = maybe_update_task_status(socket.assigns.current_task, task_id, status, socket)

    cid =
      if(updated_task && updated_task.container_id,
        do: updated_task.container_id,
        else: socket.assigns.active_container_id
      )

    user = socket.assigns.current_scope.user

    socket =
      socket
      |> assign(:current_task, updated_task)
      |> assign(:active_container_id, cid)
      |> reload_all(user.id)

    socket =
      cond do
        status in ["completed", "failed"] ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
          |> assign(:queued_messages, [])
          |> clear_optimistic_queue_snapshot(task_id)

        status == "cancelled" ->
          socket
          |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
          |> assign(:pending_question, nil)
          |> clear_optimistic_queue_snapshot(task_id)

        true ->
          socket
      end

    # Restart duration tick when a session begins running (it self-stops when
    # no running sessions exist, so we need to re-schedule here).
    if status == "running", do: schedule_duration_tick()

    {:noreply, socket}
  end

  @impl true
  def handle_info(:poll_container_stats, socket) do
    stats = poll_running_session_stats(socket.assigns.sessions)
    schedule_stats_poll()
    {:noreply, assign(socket, :container_stats, stats)}
  end

  @impl true
  def handle_info(:tick_session_durations, socket) do
    has_running =
      Enum.any?(socket.assigns.sessions, fn s ->
        s.started_at != nil and s.completed_at == nil
      end)

    if has_running, do: schedule_duration_tick()
    {:noreply, assign(socket, :duration_now, DateTime.utc_now())}
  end

  # Tagged async result from per-session auth refresh (success)
  @impl true
  def handle_info({ref, {task_id, {:ok, new_task}}}, socket)
      when is_reference(ref) and is_binary(task_id) do
    Process.demonitor(ref, [:flush])
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{new_task.id}")
    user = socket.assigns.current_scope.user

    socket =
      assign(socket, :auth_refreshing, Map.delete(socket.assigns.auth_refreshing, task_id))

    # Only update the detail pane if this is the currently viewed session
    socket =
      if match?(%{id: ^task_id}, socket.assigns.current_task) do
        is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

        socket =
          socket
          |> assign(:current_task, new_task)
          |> assign(:events, [])
          |> assign(:form, to_form(%{"instruction" => ""}))

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

    {:noreply, reload_all(socket, user.id)}
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
  def handle_info({:new_task_created, client_id, {:ok, _task}}, socket) do
    user = socket.assigns.current_scope.user

    {:noreply,
     socket
     |> clear_new_task_monitor(client_id)
     |> assign(
       :optimistic_new_sessions,
       remove_optimistic_new_session(socket.assigns.optimistic_new_sessions, client_id)
     )
     |> broadcast_optimistic_new_sessions_snapshot()
     |> reload_all(user.id)}
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
    user = socket.assigns.current_scope.user

    is_resume = match?(%{id: id} when id == new_task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, new_task)
      |> assign(:events, [])
      |> assign(:form, to_form(%{"instruction" => ""}))
      |> clear_flash()

    socket =
      if is_resume do
        socket
        |> assign(:output_parts, EventProcessor.freeze_streaming(socket.assigns.output_parts))
        |> assign(:pending_question, nil)
      else
        assign_session_state(socket)
      end

    {:noreply, reload_all(socket, user.id)}
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
  def handle_info({:queue_updated, user_id, queue_state}, socket) do
    if user_id == socket.assigns.current_scope.user.id do
      {:noreply, reload_all(socket, user_id, queue_state)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:tickets_synced, _tickets}, socket) do
    user = socket.assigns.current_scope.user
    {:noreply, reload_all(socket, user.id)}
  end

  @impl true
  def handle_info(
        {:dispatch_follow_up_message, task_id, instruction, correlation_key, queued_at},
        socket
      ) do
    caller = self()

    Task.start(fn ->
      result =
        Sessions.send_message(
          task_id,
          instruction,
          correlation_key: correlation_key,
          command_type: "follow_up_message",
          sent_at: DateTime.to_iso8601(queued_at)
        )

      send(caller, {:follow_up_send_result, correlation_key, result})
    end)

    {:noreply, socket}
  end

  @impl true
  def handle_info({:follow_up_send_result, _correlation_key, :ok}, socket), do: {:noreply, socket}

  @impl true
  def handle_info({:follow_up_send_result, correlation_key, {:error, _reason}}, socket) do
    {:noreply,
     socket
     |> assign(
       :queued_messages,
       mark_queued_message_status(socket.assigns.queued_messages, correlation_key, "rolled_back")
     )
     |> broadcast_optimistic_queue_snapshot()
     |> put_flash(:error, "Failed to send message")}
  end

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  defp mark_queued_message_status(messages, correlation_key, status) do
    Enum.map(messages, fn msg ->
      key = msg[:correlation_key] || msg[:id]
      if key == correlation_key, do: Map.put(msg, :status, status), else: msg
    end)
  end

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
      output_parts: [],
      pending_question: nil,
      confirmed_user_messages: [],
      optimistic_user_messages: [],
      user_message_ids: MapSet.new(),
      todo_items: [],
      queued_messages: []
    )
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
     |> assign(:form, to_form(%{"instruction" => ""}))
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

  defp normalize_ordered_ticket_numbers(values) when is_list(values) do
    values
    |> Enum.map(&Integer.parse(to_string(&1)))
    |> Enum.filter(&match?({_, ""}, &1))
    |> Enum.map(fn {n, _} -> n end)
  end

  defp normalize_ordered_ticket_numbers(_), do: []

  defp apply_local_ticket_reorder(tickets, moved_number, target_status, ordered_numbers) do
    case Enum.find(tickets, &(&1.number == moved_number)) do
      nil ->
        tickets

      moved_ticket ->
        destination_status =
          if is_binary(target_status) and target_status != "" do
            target_status
          else
            moved_ticket.status
          end

        moved_ticket = %{moved_ticket | status: destination_status}
        remaining_tickets = Enum.reject(tickets, &(&1.number == moved_number))

        destination_lane =
          Enum.filter(remaining_tickets, &(&1.status == destination_status))

        destination_lookup =
          Enum.reduce(destination_lane, %{moved_number => moved_ticket}, fn ticket, acc ->
            Map.put(acc, ticket.number, ticket)
          end)

        ordered_destination_lane =
          ordered_numbers
          |> Enum.uniq()
          |> Enum.map(&Map.get(destination_lookup, &1))
          |> Enum.reject(&is_nil/1)

        listed_numbers = MapSet.new(Enum.map(ordered_destination_lane, & &1.number))

        ordered_destination_lane =
          if MapSet.member?(listed_numbers, moved_number) do
            ordered_destination_lane
          else
            ordered_destination_lane ++ [moved_ticket]
          end

        destination_lane_remainder =
          Enum.reject(destination_lane, &MapSet.member?(listed_numbers, &1.number))

        untouched_tickets =
          Enum.reject(remaining_tickets, &(&1.status == destination_status))

        untouched_tickets ++ ordered_destination_lane ++ destination_lane_remainder
    end
  end

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
    trimmed = String.trim(message)
    optimistic_id = "optimistic-#{System.unique_integer([:positive])}"
    updated = socket.assigns.optimistic_user_messages ++ [trimmed]
    parts = socket.assigns.output_parts ++ [{:user_pending, optimistic_id, trimmed}]

    socket
    |> assign(:optimistic_user_messages, updated)
    |> assign(:output_parts, parts)
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
    |> append_optimistic_user_message(message)
    |> assign(:pending_question, nil)
  end

  defp handle_question_result_basic(:ok, socket, _pending, _error_msg) do
    assign(socket, :pending_question, nil)
  end

  defp handle_question_result_basic({:error, :task_not_running}, socket, pending, _error_msg) do
    message = format_question_answer_as_message(pending, build_question_answers(pending))

    socket
    |> assign(:pending_question, nil)
    |> assign(:form, to_form(%{"instruction" => message}))
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
    user = socket.assigns.current_scope.user
    Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "task:#{task.id}")

    is_resume = match?(%{id: id} when id == task.id, socket.assigns.current_task)

    socket =
      socket
      |> assign(:current_task, task)
      |> assign(:active_container_id, task.container_id)
      |> assign(:composing_new, false)
      |> assign(:form, to_form(%{"instruction" => ""}))

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

    {:noreply,
     socket
     |> reload_all(user.id)
     |> push_event("scroll_to_bottom", %{})
     |> push_event("focus_input", %{})}
  end

  defp handle_task_result({:error, reason}, socket) do
    {:noreply, put_flash(socket, :error, task_error_message(reason))}
  end

  defp do_cancel_task(task, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.cancel_task(task.id, user.id) do
      :ok ->
        updated =
          case Sessions.get_task(task.id, user.id) do
            {:ok, t} -> t
            _ -> Map.put(task, :status, "cancelled")
          end

        {:noreply,
         socket
         |> assign(:current_task, updated)
         |> reload_all(user.id)
         |> put_flash(:info, "Task cancelled")}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to cancel task")}
    end
  end

  defp maybe_update_task_status(nil, _task_id, _status, _socket), do: nil

  defp maybe_update_task_status(%{id: id} = task, task_id, _status, _socket) when id != task_id,
    do: task

  defp maybe_update_task_status(task, task_id, status, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, %{error: error} = refreshed} when status == "failed" and not is_nil(error) ->
        refreshed

      {:ok, refreshed} ->
        refreshed

      _ ->
        Map.put(task, :status, status)
    end
  end

  defp maybe_sync_status_from_session_event(
         socket,
         %{"type" => "session.status"} = event,
         task_id
       ) do
    status_type = get_in(event, ["properties", "status", "type"])

    case status_type do
      "idle" ->
        maybe_refresh_task_from_db(socket, task_id)

      _ ->
        socket
    end
  end

  defp maybe_sync_status_from_session_event(socket, _event, _task_id), do: socket

  defp maybe_refresh_task_from_db(socket, task_id) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        socket
        |> assign(:current_task, task)
        |> reload_all(user.id)

      _ ->
        socket
    end
  end

  defp reload_all(socket, user_id, queue_state_override \\ nil) do
    sessions = Sessions.list_sessions(user_id)
    tasks = Sessions.list_tasks(user_id)
    tickets = Sessions.list_project_tickets(user_id, tasks: tasks)
    sessions = merge_unassigned_active_tasks(sessions, tasks)

    active_ticket_number =
      next_active_ticket_number(tickets, socket.assigns[:active_ticket_number])

    sessions =
      case {socket.assigns[:todo_items], socket.assigns[:active_container_id]} do
        {todos, cid} when is_list(todos) and todos != [] and not is_nil(cid) ->
          todo_maps =
            Enum.map(todos, fn item ->
              %{
                "id" => item[:id],
                "title" => item[:title],
                "status" => item[:status],
                "position" => item[:position]
              }
            end)

          update_session_todo_items(sessions, cid, todo_maps)

        _ ->
          sessions
      end

    socket
    |> assign(:sessions, sessions)
    |> assign(:tickets, tickets)
    |> assign(:active_ticket_number, active_ticket_number)
    |> assign(:queue_state, queue_state_override || load_queue_state(user_id))
  end

  defp find_ticket_number_for_container(tickets, container_id) do
    case Enum.find(tickets, &(&1.associated_container_id == container_id)) do
      %{number: number} -> number
      _ -> nil
    end
  end

  defp find_ticket_number_for_selected_session(sessions, tickets, container_id) do
    case find_ticket_number_for_container(tickets, container_id) do
      number when is_integer(number) ->
        number

      _ ->
        sessions
        |> Enum.find(&(&1.container_id == container_id))
        |> case do
          %{title: title} when is_binary(title) ->
            case Sessions.extract_ticket_number(title) do
              number when is_integer(number) and number > 0 ->
                if Enum.any?(tickets, &(&1.number == number)), do: number, else: nil

              _ ->
                nil
            end

          _ ->
            nil
        end
    end
  end

  defp next_active_ticket_number([], _current), do: nil

  defp next_active_ticket_number(tickets, current) do
    case Enum.find(tickets, &(&1.number == current)) do
      %{number: number} -> number
      _ -> tickets |> List.first() |> then(&(&1 && &1.number))
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

  defp schedule_stats_poll do
    Process.send_after(self(), :poll_container_stats, @stats_interval_ms)
  end

  defp schedule_duration_tick do
    Process.send_after(self(), :tick_session_durations, @duration_tick_ms)
  end

  defp update_session_todo_items(sessions, container_id, todo_maps) do
    Enum.map(sessions, fn
      %{container_id: ^container_id} = session ->
        Map.put(session, :todo_items, %{"items" => todo_maps})

      session ->
        session
    end)
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
end
