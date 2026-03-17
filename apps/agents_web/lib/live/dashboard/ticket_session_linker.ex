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

  import AgentsWeb.DashboardLive.SessionDataHelpers,
    only: [upsert_task_snapshot: 2, remove_tasks_for_container: 2]

  require Logger

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets
  alias Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy

  @doc """
  Persists a ticket-task association and reloads tickets from DB.

  When `opts` includes `ticket_number`, the association is created explicitly
  via `Tickets.link_ticket_to_session/2` — no regex extraction. When no
  `ticket_number` is provided, falls back to regex extraction from instruction
  text (deprecated, for backward compatibility only).

  The task is also upserted into `tasks_snapshot` so enrichment can derive
  display state immediately.

  Returns the updated socket.
  """
  @spec link_and_refresh(Phoenix.LiveView.Socket.t(), map(), keyword()) ::
          Phoenix.LiveView.Socket.t()
  def link_and_refresh(socket, task, opts \\ []) do
    ticket_number = Keyword.get(opts, :ticket_number)

    if is_integer(ticket_number) and ticket_number > 0 do
      persist_explicit_ticket_link(ticket_number, task)
    else
      # Deprecated: regex-based fallback. Will be removed once all callers
      # pass ticket_number explicitly.
      persist_ticket_link(task)
    end

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

  defp persist_explicit_ticket_link(ticket_number, task) do
    # session_ref_id is the UUID FK to the sessions table (not the SDK session ID).
    # It is available on the Task domain entity since it's mapped from TaskSchema.
    session_ref_id = Map.get(task, :session_ref_id)

    # Link both session and task for backward compatibility.
    # Session linking is the preferred mechanism; task linking will be
    # phased out once session-based enrichment is verified stable.
    if is_binary(session_ref_id) do
      case Tickets.link_ticket_to_session(ticket_number, session_ref_id) do
        {:ok, _} ->
          :ok

        {:error, reason} ->
          Logger.warning(
            "persist_explicit_ticket_link (session) failed for ticket ##{ticket_number}: #{inspect(reason)}"
          )
      end
    end

    case Tickets.link_ticket_to_task(ticket_number, task.id) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning(
          "persist_explicit_ticket_link (task) failed for ticket ##{ticket_number}: #{inspect(reason)}"
        )
    end
  rescue
    error ->
      Logger.warning("persist_explicit_ticket_link crashed: #{inspect(error)}")
      :ok
  end

  # Deprecated: regex-based fallback. Will be removed once all callers
  # pass ticket_number explicitly via link_and_refresh/3.
  defp persist_ticket_link(task) do
    instruction = Map.get(task, :instruction, "")

    case Tickets.extract_ticket_number(instruction) do
      nil ->
        :ok

      ticket_number ->
        case Tickets.link_ticket_to_task(ticket_number, task.id) do
          {:ok, _} ->
            :ok

          {:error, reason} ->
            Logger.warning(
              "persist_ticket_link failed for ticket ##{ticket_number}: #{inspect(reason)}"
            )
        end
    end
  rescue
    error ->
      Logger.warning("persist_ticket_link crashed: #{inspect(error)}")
      :ok
  end
end
