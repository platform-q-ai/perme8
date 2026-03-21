defmodule AgentsWeb.DashboardLive.SessionDataHelpers do
  @moduledoc """
  Delegation hub for dashboard session data helpers.

  Re-exports all helper functions for backward compatibility. Callers that
  `import AgentsWeb.DashboardLive.SessionDataHelpers` get access to all
  functions without needing to know which sub-module defines them.

  Actual implementations live in:
  - `AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers`
  - `AgentsWeb.DashboardLive.Helpers.TicketDataHelpers`
  - `AgentsWeb.DashboardLive.Helpers.SessionStateHelpers`
  - `AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers`
  """

  # -- OptimisticQueueHelpers --
  defdelegate normalize_hydrated_queue_entry(entry),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate parse_hydrated_datetime(value),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate normalize_hydrated_new_session_entry(entry),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate merge_optimistic_new_sessions(existing, incoming),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate remove_optimistic_new_session(entries, client_id),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate stale_optimistic_entry?(entry),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate already_has_real_session?(entry, sessions),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate normalize_ordered_ticket_numbers(values),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate merge_queued_messages(existing, incoming),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate maybe_sync_optimistic_queue_snapshot(socket, previous_queue),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate broadcast_optimistic_queue_snapshot(socket),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate clear_optimistic_queue_snapshot(socket, task_id),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate clear_new_task_monitor(socket, client_id),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate maybe_flash_new_task_down(socket, reason),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate broadcast_optimistic_new_sessions_snapshot(socket),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate serialize_optimistic_new_sessions(entries),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate serialize_queued_messages(messages),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  defdelegate serialize_queued_datetime(dt),
    to: AgentsWeb.DashboardLive.Helpers.OptimisticQueueHelpers

  # -- TicketDataHelpers --
  defdelegate map_ticket_tree(tickets, fun), to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers
  defdelegate all_tickets(tickets), to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate find_ticket_by_number(tickets, number),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate update_ticket_by_number(tickets, number, update_fn),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate lifecycle_ticket_match?(ticket, ticket_id),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate find_parent_ticket(tickets, ticket),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate find_ticket_number_for_container(tickets, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate find_ticket_number_for_selected_session(sessions, tickets, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate extract_ticket_number_from_session(sessions, tickets, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate next_active_ticket_number(tickets, current),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate resolve_container_for_ticket(ticket, tasks_snapshot),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate resolve_container_from_task_id(task_id, tasks_snapshot),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate ticket_owns_current_task?(ticket, current_task),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate ensure_ticket_reference(instruction, ticket_number, ticket),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  defdelegate parse_ticket_number_param(params),
    to: AgentsWeb.DashboardLive.Helpers.TicketDataHelpers

  # -- SessionStateHelpers --
  defdelegate assign_session_state(socket),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate upsert_session_from_task(sessions, task),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate build_session_from_task(task, task_id, task_container_id),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate drop_default_fields(session_update, task),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate derive_container_id(cid, task_id),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate split_matching_sessions(sessions, task_id, task_container_id),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate matches_container?(session, cid),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate sort_sessions_for_sidebar(sessions),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate running_session?(session), to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers
  defdelegate latest_at_unix(session), to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate merge_unassigned_active_tasks(sessions, tasks),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate has_real_container?(session),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate upsert_task_snapshot(tasks, task),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate remove_tasks_for_container(tasks, container_id),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate update_task_lifecycle_state(tasks, task_id, lifecycle_state),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate update_session_lifecycle_state(sessions, task_id, lifecycle_state),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate lifecycle_state_to_string(state),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate lifecycle_state_for_task_status(task, status),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate update_session_todo_items(sessions, container_id, todo_maps),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate subscribe_to_active_tasks(tasks),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate hydrate_task_for_session(task, user_id),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate resolve_new_task_ack_task(task, user_id, optimistic_entry),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  defdelegate find_task_by_instruction(user_id, instruction),
    to: AgentsWeb.DashboardLive.Helpers.SessionStateHelpers

  # -- TaskExecutionHelpers --
  defdelegate session_tabs(), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers
  defdelegate session_tabs(has_pr_tab), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_active_tab(params, has_ticket_tab?),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_active_tab(params, has_ticket_tab?, has_pr_tab?),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate linked_pull_request_for_ticket(ticket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_active_ticket_number(
                params,
                selected_container_id,
                sessions,
                tickets,
                current
              ),
              to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate tasks_snapshot_or_reload(socket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_selected_container_id(params, sessions),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate default_container_id(sessions),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_current_task(params, tasks, selected_container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate delete_queued_task_by_id(task_id, user_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_queued_delete(task_id, container_id, user_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate clear_deleted_selection(socket, task_id, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_put_container(params, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_put_new(params, value),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate clear_form(socket), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers
  defdelegate prefill_form(socket, text), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate route_message_submission(route, socket, instruction, ticket_number, ticket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate send_message_to_running_task(socket, instruction),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate append_optimistic_user_message(socket, message),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate append_answer_submitted_message(socket, message),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate append_optimistic_part(socket, message, tag),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate remove_answer_submitted_part(socket, message),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate toggle_selection(current, label, multiple),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate build_question_answers(pending),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate format_question_answer_as_message(pending, answers),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate submit_active_question(socket, pending, task_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate run_or_resume_task(socket, instruction, ticket_number),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate run_or_resume_task(socket, instruction, ticket_number, ticket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate handle_task_result(result, socket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate do_cancel_task(task, socket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate do_cancel_task(task, socket, flash_message),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate perform_cancel_task(task, socket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate fetch_cancelled_task(task, user_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate recover_instruction(updated_task, original_task),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate resolve_changed_task(is_current, updated_current_task, task_id, status, socket),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate apply_status_change_to_ui(socket, is_current, status, task_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_sync_status_from_session_event(socket, event, task_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate request_task_refresh(socket, task_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate derive_sticky_warm_task_ids(sessions, queue_state, previous_sticky),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate load_queue_state(user_id), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers
  defdelegate default_queue_state(), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers
  defdelegate reload_tickets(socket), to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate apply_ticket_closed(socket, number),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_revert_optimistic_ticket(socket, ticket_number),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate update_ticket_lifecycle_assigns(socket, ticket_id, to_stage, transitioned_at),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_delete_session(container_id, user_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_remove_tasks(tasks_snapshot, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_reject_session(sessions, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate tab_after_ticket_close(assigns, number),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers

  defdelegate maybe_clear_active_session(socket, container_id),
    to: AgentsWeb.DashboardLive.Helpers.TaskExecutionHelpers
end
