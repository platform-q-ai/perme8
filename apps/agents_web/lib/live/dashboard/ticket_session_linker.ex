defmodule AgentsWeb.DashboardLive.TicketSessionLinker do
  @moduledoc """
  Single authority for ticket-session linking operations.

  This module centralises all link/unlink/refresh operations that maintain the
  bidirectional relationship between tickets and sessions (tasks). It operates
  on `Phoenix.LiveView.Socket` assigns and delegates persistence to the
  `Agents.Tickets` context.

  ## Responsibilities

  - **link_and_refresh/2** — Persist a ticket-task FK association and reload
    tickets from DB so the UI immediately reflects the link.
  - **unlink_and_refresh/2** — Clear a ticket-task FK and reload tickets.
  - **cleanup_and_refresh/3** — Remove tasks for a destroyed container from the
    in-memory snapshot and re-enrich tickets against the cleaned snapshot.
  - **refresh_tickets/1** — Reload tickets from DB using the current snapshot.

  All handler modules should go through this module rather than directly calling
  `Tickets.link_ticket_to_task/2`, `Tickets.unlink_ticket_from_task/1`, or
  inlining enrichment logic.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy

  @doc """
  Persists a ticket-task association (if the task's instruction references a
  ticket number) and reloads tickets from DB.

  The task is also upserted into `tasks_snapshot` so enrichment can derive
  display state immediately. Exceptions from `link_ticket_to_task` are rescued
  to match the existing fault-tolerant behaviour.

  Returns the updated socket.
  """
  @spec link_and_refresh(Phoenix.LiveView.Socket.t(), map()) :: Phoenix.LiveView.Socket.t()
  def link_and_refresh(socket, task) do
    persist_ticket_link(task)

    tasks_snapshot = upsert_task_snapshot(socket.assigns[:tasks_snapshot], task)
    user_id = socket.assigns.current_scope.user.id

    tickets = Tickets.list_project_tickets(user_id, tasks: tasks_snapshot)

    socket
    |> assign(:tasks_snapshot, tasks_snapshot)
    |> assign(:tickets, tickets)
  end

  @doc """
  Clears the ticket-task FK for the given ticket number and reloads tickets
  from DB.

  Returns the updated socket.
  """
  @spec unlink_and_refresh(Phoenix.LiveView.Socket.t(), integer()) ::
          Phoenix.LiveView.Socket.t()
  def unlink_and_refresh(socket, ticket_number) do
    Tickets.unlink_ticket_from_task(ticket_number)

    refresh_tickets(socket)
  end

  @doc """
  Removes tasks for a destroyed container from the in-memory snapshot and
  re-enriches tickets against the cleaned snapshot.

  This is a pure function (no DB calls) that matches the existing
  `purge_tasks_and_reenrich/3` signature.

  Returns `{cleaned_tasks_snapshot, enriched_tickets}`.
  """
  @spec cleanup_and_refresh(list(), list(), String.t()) :: {list(), list()}
  def cleanup_and_refresh(tasks_snapshot, tickets, container_id) do
    old_tasks = tasks_snapshot || []
    cleaned = remove_tasks_for_container(old_tasks, container_id)

    enriched_tickets =
      TicketEnrichmentPolicy.enrich_all(
        tickets,
        cleaned,
        &SessionLifecyclePolicy.derive/1
      )

    {cleaned, enriched_tickets}
  end

  @doc """
  Reloads tickets from DB using the current `tasks_snapshot` assign.

  Returns the updated socket with fresh `:tickets`.
  """
  @spec refresh_tickets(Phoenix.LiveView.Socket.t()) :: Phoenix.LiveView.Socket.t()
  def refresh_tickets(socket) do
    user_id = socket.assigns.current_scope.user.id
    tasks_snapshot = socket.assigns[:tasks_snapshot] || []

    tickets = Tickets.list_project_tickets(user_id, tasks: tasks_snapshot)

    assign(socket, :tickets, tickets)
  end

  # -- Private helpers -------------------------------------------------------

  defp persist_ticket_link(task) do
    instruction = Map.get(task, :instruction, "")

    case Tickets.extract_ticket_number(instruction) do
      nil -> :ok
      ticket_number -> Tickets.link_ticket_to_task(ticket_number, task.id)
    end
  rescue
    _ -> :ok
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

  defp remove_tasks_for_container(tasks, _container_id) when not is_list(tasks), do: tasks

  defp remove_tasks_for_container(tasks, container_id) when is_binary(container_id) do
    Enum.reject(tasks, fn task ->
      task_cid = Map.get(task, :container_id)
      task_id = Map.get(task, :id)

      task_cid == container_id or
        (is_binary(task_id) and "task:#{task_id}" == container_id)
    end)
  end
end
