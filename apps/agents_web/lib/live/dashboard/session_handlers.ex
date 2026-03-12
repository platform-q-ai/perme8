defmodule AgentsWeb.DashboardLive.SessionHandlers do
  @moduledoc false

  use Phoenix.VerifiedRoutes,
    endpoint: AgentsWeb.Endpoint,
    router: AgentsWeb.Router,
    statics: AgentsWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3, push_patch: 2, put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers
  import AgentsWeb.DashboardLive.Helpers, only: [task_error_message: 1]

  alias Agents.Sessions
  alias AgentsWeb.DashboardLive.TicketSessionLinker

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

  def new_session(_params, socket) do
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

  def select_session(%{"container-id" => container_id}, socket) do
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

  def delete_session(%{"container-id" => container_id}, socket) do
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

  def delete_queued_task(params, socket) do
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

  def select_image(%{"image" => image}, socket) do
    {:noreply, assign(socket, :selected_image, image)}
  end

  def session_search(%{"session_search" => query}, socket) do
    {:noreply, assign(socket, :session_search, String.trim(query))}
  end

  def clear_session_search(_params, socket) do
    {:noreply, assign(socket, :session_search, "")}
  end

  def status_filter(%{"status" => status}, socket) do
    case Map.get(@valid_status_filters, status) do
      nil -> {:noreply, socket}
      filter -> {:noreply, assign(socket, :status_filter, filter)}
    end
  end

  def switch_tab(%{"tab" => tab}, socket) do
    valid_tabs = Enum.map(AgentsWeb.DashboardLive.Index.session_tabs(), & &1.id)
    tab = if tab in valid_tabs, do: tab, else: "chat"

    params =
      %{"tab" => tab}
      |> maybe_put_container(socket.assigns.active_container_id)
      |> maybe_put_new(socket.assigns.composing_new)

    {:noreply, push_patch(socket, to: ~p"/sessions?#{params}")}
  end

  def update_concurrency_limit(%{"concurrency_limit" => limit_str}, socket) do
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

  def update_warm_cache_limit(%{"warm_cache_limit" => limit_str}, socket) do
    user = socket.assigns.current_scope.user

    case Integer.parse(limit_str) do
      {limit, ""} when limit >= 0 and limit <= 5 ->
        Sessions.set_warm_cache_limit(user.id, limit)
        {:noreply, socket}

      _ ->
        {:noreply, socket}
    end
  end

  def pause_session(%{"task-id" => task_id}, socket) do
    user = socket.assigns.current_scope.user

    case Sessions.get_task(task_id, user.id) do
      {:ok, task} ->
        do_cancel_task(task, socket, "Session paused")

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to find task")}
    end
  end

  def hydrate_optimistic_queue(
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

  def hydrate_optimistic_queue(_params, socket), do: {:noreply, socket}

  def hydrate_optimistic_new_sessions(%{"entries" => entries}, socket)
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

  def hydrate_optimistic_new_sessions(_params, socket), do: {:noreply, socket}
end
