defmodule AgentsWeb.DashboardLive.TicketHandlers do
  @moduledoc "Handles ticket CRUD events, queue management, and ticket-session linking from the dashboard UI."

  use Phoenix.VerifiedRoutes,
    endpoint: AgentsWeb.Endpoint,
    router: AgentsWeb.Router,
    statics: AgentsWeb.static_paths()

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [push_event: 3, push_patch: 2, put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers

  alias Agents.Sessions
  alias Agents.Tickets
  alias AgentsWeb.DashboardLive.TicketSessionLinker

  require Logger

  def create_ticket(%{"body" => body}, socket) do
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

  def reorder_triage_tickets(%{"ordered_numbers" => ordered}, socket) do
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

  def send_ticket_to_top(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        Tickets.send_ticket_to_top(number)
        tickets = reload_tickets(socket)
        {:noreply, assign(socket, :tickets, tickets)}

      _ ->
        {:noreply, socket}
    end
  end

  def send_ticket_to_bottom(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        Tickets.send_ticket_to_bottom(number)
        tickets = reload_tickets(socket)
        {:noreply, assign(socket, :tickets, tickets)}

      _ ->
        {:noreply, socket}
    end
  end

  def select_ticket(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} -> do_select_ticket(number, socket)
      _ -> {:noreply, socket}
    end
  end

  defp do_select_ticket(number, socket) do
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

  def toggle_parent_collapse(%{"ticket-id" => ticket_id}, socket) do
    collapsed_parents = socket.assigns[:collapsed_parents] || MapSet.new()

    updated =
      if MapSet.member?(collapsed_parents, ticket_id) do
        MapSet.delete(collapsed_parents, ticket_id)
      else
        MapSet.put(collapsed_parents, ticket_id)
      end

    {:noreply, assign(socket, :collapsed_parents, updated)}
  end

  def simulate_ticket_transition_in_progress_to_in_review(_params, socket) do
    transitioned_at = DateTime.utc_now() |> DateTime.truncate(:second)
    send(self(), {:ticket_stage_changed, 402, "in_review", transitioned_at})
    {:noreply, socket}
  end

  def close_ticket(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        case Tickets.close_project_ticket(number) do
          :ok ->
            {:noreply, apply_ticket_closed(socket, number)}

          {:error, _reason} ->
            {:noreply,
             put_flash(socket, :error, "Failed to close ticket on GitHub. Please try again.")}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def sync_tickets(_params, socket) do
    lv = self()

    Task.start(fn ->
      result = Tickets.sync_tickets()
      send(lv, {:ticket_sync_finished, result})
    end)

    {:noreply, assign(socket, :syncing_tickets, true)}
  end

  def start_ticket_session(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} -> do_start_ticket_session(number, socket)
      _ -> {:noreply, socket}
    end
  end

  defp do_start_ticket_session(number, socket) do
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

  def remove_ticket_from_queue(%{"number" => number_str}, socket) do
    case Integer.parse(number_str) do
      {number, ""} ->
        ticket = find_ticket_by_number(socket.assigns.tickets, number)

        cond do
          is_nil(ticket) ->
            {:noreply, put_flash(socket, :error, "Ticket not found")}

          is_nil(ticket.associated_task_id) ->
            {:noreply, put_flash(socket, :error, "Ticket has no associated task")}

          true ->
            cancel_and_unlink_ticket(ticket, number, socket)
        end

      _ ->
        {:noreply, socket}
    end
  end

  defp cancel_and_unlink_ticket(ticket, number, socket) do
    case Sessions.get_task(ticket.associated_task_id, socket.assigns.current_scope.user.id) do
      {:ok, task} ->
        case perform_cancel_task(task, socket) do
          {:ok, socket} ->
            # Clear the persisted FK so the ticket doesn't re-associate
            # on next page reload (Bug 1 fix).
            socket = TicketSessionLinker.unlink_and_refresh(socket, number)

            {:noreply, put_flash(socket, :info, "Ticket ##{number} paused and moved to triage")}

          {:error, socket} ->
            {:noreply, socket}
        end

      {:error, _} ->
        {:noreply, put_flash(socket, :error, "Failed to find task for ticket ##{number}")}
    end
  end
end
