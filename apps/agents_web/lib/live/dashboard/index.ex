defmodule AgentsWeb.DashboardLive.Index do
  @moduledoc "LiveView for the session manager — split-panel layout with session list, output log, and task controls."

  use AgentsWeb, :live_view

  import AgentsWeb.DashboardLive.Components.SessionComponents
  import AgentsWeb.DashboardLive.Components.SidebarComponents
  import AgentsWeb.DashboardLive.Components.DetailPanelComponents
  import AgentsWeb.DashboardLive.Helpers
  import AgentsWeb.DashboardLive.SessionDataHelpers

  import AgentsWeb.DashboardLive.TicketLifecycleFixtures,
    only: [maybe_apply_ticket_lifecycle_fixture: 2]

  alias Agents.Sessions
  alias Agents.Sessions.Domain.Entities.QueueSnapshot
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Events.TicketStageChanged

  alias AgentsWeb.DashboardLive.AuthRefreshHandlers
  alias AgentsWeb.DashboardLive.DependencyHandlers
  alias AgentsWeb.DashboardLive.EventProcessor
  alias AgentsWeb.DashboardLive.FollowUpDispatchHandlers
  alias AgentsWeb.DashboardLive.PubSubHandlers
  alias AgentsWeb.DashboardLive.QuestionHandlers
  alias AgentsWeb.DashboardLive.SessionHandlers
  alias AgentsWeb.DashboardLive.TaskExecutionHandlers
  alias AgentsWeb.DashboardLive.TicketHandlers

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_scope.user
    sessions = Sessions.list_sessions(user.id)
    tasks = Sessions.list_tasks(user.id)
    tickets = Tickets.list_project_tickets(user.id, tasks: tasks)
    active_ticket_number = next_active_ticket_number(tickets, nil)
    queue_snapshot = load_queue_state(user.id) || empty_queue_snapshot(user.id)
    queue_state = QueueSnapshot.to_legacy_map(queue_snapshot)

    if connected?(socket) do
      subscribe_to_active_tasks(tasks)
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "queue:user:#{user.id}")
      Phoenix.PubSub.subscribe(Perme8.Events.PubSub, "sessions:user:#{user.id}")
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
     |> assign(:dependency_search_mode, false)
     |> assign(:dependency_search_results, [])
     |> assign(:dependency_search_query, "")
     |> assign(:selected_dependency_target, nil)
     |> assign(:dependency_direction, nil)
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
     |> push_event("focus_input", %{})
     |> maybe_push_draft_key(active_ticket_number)}
  end

  # -- Task Execution Handlers ------------------------------------------------

  @impl true
  def handle_event("run_task", params, socket),
    do: TaskExecutionHandlers.run_task(params, socket)

  @impl true
  def handle_event("cancel_task", params, socket),
    do: TaskExecutionHandlers.cancel_task(params, socket)

  @impl true
  def handle_event("restart_session", params, socket),
    do: TaskExecutionHandlers.restart_session(params, socket)

  # -- Ticket Handlers ---------------------------------------------------------

  @impl true
  def handle_event("create_ticket", params, socket),
    do: TicketHandlers.create_ticket(params, socket)

  @impl true
  def handle_event("reorder_triage_tickets", params, socket),
    do: TicketHandlers.reorder_triage_tickets(params, socket)

  @impl true
  def handle_event("send_ticket_to_top", params, socket),
    do: TicketHandlers.send_ticket_to_top(params, socket)

  @impl true
  def handle_event("send_ticket_to_bottom", params, socket),
    do: TicketHandlers.send_ticket_to_bottom(params, socket)

  @impl true
  def handle_event("select_ticket", params, socket),
    do: TicketHandlers.select_ticket(params, socket)

  @impl true
  def handle_event("toggle_parent_collapse", params, socket),
    do: TicketHandlers.toggle_parent_collapse(params, socket)

  @impl true
  def handle_event("simulate_ticket_transition_in_progress_to_in_review", params, socket),
    do: TicketHandlers.simulate_ticket_transition_in_progress_to_in_review(params, socket)

  @impl true
  def handle_event("close_ticket", params, socket),
    do: TicketHandlers.close_ticket(params, socket)

  @impl true
  def handle_event("sync_tickets", params, socket),
    do: TicketHandlers.sync_tickets(params, socket)

  @impl true
  def handle_event("start_ticket_session", params, socket),
    do: TicketHandlers.start_ticket_session(params, socket)

  @impl true
  def handle_event("remove_ticket_from_queue", params, socket),
    do: TicketHandlers.remove_ticket_from_queue(params, socket)

  @impl true
  def handle_event("update_ticket_labels", params, socket),
    do: TicketHandlers.update_ticket_labels(params, socket)

  # -- Dependency Handlers -----------------------------------------------------

  @impl true
  def handle_event("add_dependency_start", params, socket),
    do: DependencyHandlers.add_dependency_start(params, socket)

  @impl true
  def handle_event("cancel_dependency", params, socket),
    do: DependencyHandlers.cancel_dependency(params, socket)

  @impl true
  def handle_event("dependency_search", params, socket),
    do: DependencyHandlers.dependency_search(params, socket)

  @impl true
  def handle_event("select_dependency_target", params, socket),
    do: DependencyHandlers.select_dependency_target(params, socket)

  @impl true
  def handle_event("set_dependency_direction", params, socket),
    do: DependencyHandlers.set_dependency_direction(params, socket)

  @impl true
  def handle_event("confirm_dependency", params, socket),
    do: DependencyHandlers.confirm_dependency(params, socket)

  @impl true
  def handle_event("remove_dependency", params, socket),
    do: DependencyHandlers.remove_dependency(params, socket)

  # -- Session Handlers --------------------------------------------------------

  @impl true
  def handle_event("new_session", params, socket),
    do: SessionHandlers.new_session(params, socket)

  @impl true
  def handle_event("select_session", params, socket),
    do: SessionHandlers.select_session(params, socket)

  @impl true
  def handle_event("delete_session", params, socket),
    do: SessionHandlers.delete_session(params, socket)

  @impl true
  def handle_event("delete_queued_task", params, socket),
    do: SessionHandlers.delete_queued_task(params, socket)

  @impl true
  def handle_event("select_image", params, socket),
    do: SessionHandlers.select_image(params, socket)

  @impl true
  def handle_event("session_search", params, socket),
    do: SessionHandlers.session_search(params, socket)

  @impl true
  def handle_event("clear_session_search", params, socket),
    do: SessionHandlers.clear_session_search(params, socket)

  @impl true
  def handle_event("status_filter", params, socket),
    do: SessionHandlers.status_filter(params, socket)

  @impl true
  def handle_event("switch_tab", params, socket),
    do: SessionHandlers.switch_tab(params, socket)

  @impl true
  def handle_event("pause_session", params, socket),
    do: SessionHandlers.pause_session(params, socket)

  @impl true
  def handle_event("hydrate_optimistic_queue", params, socket),
    do: SessionHandlers.hydrate_optimistic_queue(params, socket)

  @impl true
  def handle_event("hydrate_optimistic_new_sessions", params, socket),
    do: SessionHandlers.hydrate_optimistic_new_sessions(params, socket)

  # -- Question Handlers -------------------------------------------------------

  @impl true
  def handle_event("toggle_question_option", params, socket),
    do: QuestionHandlers.toggle_question_option(params, socket)

  @impl true
  def handle_event("update_question_form", params, socket),
    do: QuestionHandlers.update_question_form(params, socket)

  @impl true
  def handle_event("submit_question_answer", params, socket),
    do: QuestionHandlers.submit_question_answer(params, socket)

  @impl true
  def handle_event("dismiss_question", params, socket),
    do: QuestionHandlers.dismiss_question(params, socket)

  # -- Auth Refresh Handlers ---------------------------------------------------

  @impl true
  def handle_event("refresh_auth_and_resume", params, socket),
    do: AuthRefreshHandlers.refresh_auth_and_resume(params, socket)

  @impl true
  def handle_event("refresh_all_auth", params, socket),
    do: AuthRefreshHandlers.refresh_all_auth(params, socket)

  # -- PubSub Handlers (handle_info) -------------------------------------------

  @impl true
  def handle_info({:task_event, task_id, event}, socket),
    do: PubSubHandlers.task_event(task_id, event, socket)

  @impl true
  def handle_info({:answer_question_async, task_id, request_id, answers, message}, socket),
    do: PubSubHandlers.answer_question_async(task_id, request_id, answers, message, socket)

  @impl true
  def handle_info({:todo_updated, task_id, todo_items}, socket),
    do: PubSubHandlers.todo_updated(task_id, todo_items, socket)

  @impl true
  def handle_info({:task_status_changed, task_id, status}, socket),
    do: PubSubHandlers.task_status_changed(task_id, status, socket)

  @impl true
  def handle_info({:lifecycle_state_changed, task_id, _from_state, to_state}, socket),
    do: PubSubHandlers.lifecycle_state_changed(task_id, to_state, socket)

  @impl true
  def handle_info({:container_stats_updated, _task_id, container_id, stats}, socket),
    do: PubSubHandlers.container_stats_updated(container_id, stats, socket)

  # Tagged async result from per-session auth refresh (success)
  @impl true
  def handle_info({ref, {task_id, {:ok, new_task}}}, socket)
      when is_reference(ref) and is_binary(task_id),
      do: PubSubHandlers.tagged_auth_refresh_ok(ref, task_id, new_task, socket)

  # Tagged async result from per-session auth refresh (error)
  @impl true
  def handle_info({ref, {task_id, {:error, reason}}}, socket)
      when is_reference(ref) and is_binary(task_id),
      do: PubSubHandlers.tagged_auth_refresh_error(ref, task_id, reason, socket)

  @impl true
  def handle_info({:new_task_created, client_id, {:ok, task}}, socket),
    do: PubSubHandlers.new_task_created_ok(client_id, task, socket)

  @impl true
  def handle_info({:new_task_created, client_id, {:error, reason}}, socket),
    do: PubSubHandlers.new_task_created_error(client_id, reason, socket)

  # Untagged async result (from run_or_resume_task — not auth refresh)
  @impl true
  def handle_info({ref, {:ok, new_task}}, socket) when is_reference(ref),
    do: PubSubHandlers.untagged_async_ok(ref, new_task, socket)

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref),
    do: PubSubHandlers.untagged_async_error(ref, reason, socket)

  @impl true
  def handle_info({:DOWN, ref, :process, _pid, reason}, socket),
    do: PubSubHandlers.down(ref, reason, socket)

  @impl true
  def handle_info({:queue_snapshot, user_id, %QueueSnapshot{} = snapshot}, socket)
      when user_id == socket.assigns.current_scope.user.id,
      do: PubSubHandlers.queue_snapshot(snapshot, socket)

  @impl true
  def handle_info({:tickets_synced, _tickets}, socket),
    do: PubSubHandlers.tickets_synced(socket)

  @impl true
  def handle_info({:ticket_stage_changed, ticket_id, to_stage, transitioned_at}, socket),
    do: PubSubHandlers.ticket_stage_changed(ticket_id, to_stage, transitioned_at, socket)

  @impl true
  def handle_info(%TicketStageChanged{} = event, socket),
    do: PubSubHandlers.ticket_stage_changed_event(event, socket)

  @impl true
  def handle_info({:ticket_sync_finished, _result}, socket),
    do: PubSubHandlers.ticket_sync_finished(socket)

  @impl true
  def handle_info({:task_refreshed, task_id, {:ok, task}}, socket),
    do: PubSubHandlers.task_refreshed_ok(task_id, task, socket)

  @impl true
  def handle_info({:task_refreshed, task_id, _}, socket),
    do: PubSubHandlers.task_refreshed_error(task_id, socket)

  # -- Follow-Up Dispatch Handlers ---------------------------------------------

  @impl true
  def handle_info(
        {:dispatch_follow_up_message, task_id, instruction, correlation_key, queued_at},
        socket
      ),
      do:
        FollowUpDispatchHandlers.dispatch_follow_up_message(
          task_id,
          instruction,
          correlation_key,
          queued_at,
          socket
        )

  @impl true
  def handle_info({:follow_up_send_result, correlation_key, result}, socket),
    do: FollowUpDispatchHandlers.follow_up_send_result(correlation_key, result, socket)

  @impl true
  def handle_info({:follow_up_timeout, correlation_key, timeout_ref}, socket),
    do: FollowUpDispatchHandlers.follow_up_timeout(correlation_key, timeout_ref, socket)

  # -- Orphan recovery notification --------------------------------------------

  @impl true
  def handle_info({:sessions_orphaned, count, task_ids}, socket),
    do: PubSubHandlers.sessions_orphaned(count, task_ids, socket)

  # -- Catch-all ---------------------------------------------------------------

  @impl true
  def handle_info(_msg, socket), do: {:noreply, socket}

  def ticket_data_id(ticket) do
    Map.get(ticket, :external_id) || "ticket-#{ticket.number}"
  end

  defp empty_queue_snapshot(user_id) do
    QueueSnapshot.new(%{
      user_id: user_id,
      lanes: %{
        processing: [],
        warm: [],
        cold: [],
        awaiting_feedback: [],
        retry_pending: []
      },
      metadata: %{
        concurrency_limit: Sessions.get_concurrency_limit(user_id),
        running_count: 0,
        warm_cache_limit: 2
      }
    })
  rescue
    _ ->
      QueueSnapshot.new(%{
        user_id: user_id,
        lanes: %{
          processing: [],
          warm: [],
          cold: [],
          awaiting_feedback: [],
          retry_pending: []
        },
        metadata: %{concurrency_limit: 2, running_count: 0, warm_cache_limit: 2}
      })
  end

  # Push a switch_draft_key event to the SessionFormHook when a ticket is active.
  # This fires AFTER handle_params completes, ensuring the LiveView socket is
  # stable and the hook receives the event reliably.
  defp maybe_push_draft_key(socket, ticket_number) when is_integer(ticket_number) do
    Phoenix.LiveView.push_event(socket, "switch_draft_key", %{key: "ticket:#{ticket_number}"})
  end

  defp maybe_push_draft_key(socket, _), do: socket
end
