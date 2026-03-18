defmodule AgentsWeb.DashboardLive.DependencyHandlers do
  @moduledoc "Handles ticket dependency (blocks/blocked-by) events from the dashboard UI."

  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [put_flash: 3]
  import AgentsWeb.DashboardLive.SessionDataHelpers

  alias Agents.Tickets

  require Logger

  def add_dependency_start(_params, socket) do
    {:noreply,
     socket
     |> assign(:dependency_search_mode, true)
     |> assign(:dependency_search_results, [])
     |> assign(:dependency_search_query, "")
     |> assign(:selected_dependency_target, nil)
     |> assign(:dependency_direction, nil)}
  end

  def cancel_dependency(_params, socket) do
    {:noreply, reset_dependency_assigns(socket)}
  end

  def dependency_search(%{"value" => query}, socket) do
    query = String.trim(query)

    if query == "" do
      {:noreply,
       socket
       |> assign(:dependency_search_results, [])
       |> assign(:dependency_search_query, query)}
    else
      active_ticket = find_active_ticket(socket)

      results =
        if active_ticket do
          Tickets.search_tickets_for_dependency(query, active_ticket.number)
        else
          []
        end

      {:noreply,
       socket
       |> assign(:dependency_search_results, results)
       |> assign(:dependency_search_query, query)}
    end
  end

  def select_dependency_target(%{"ticket-id" => id_str}, socket) do
    case Integer.parse(id_str) do
      {id, ""} -> {:noreply, assign(socket, :selected_dependency_target, id)}
      _ -> {:noreply, socket}
    end
  end

  def set_dependency_direction(%{"direction" => direction}, socket)
      when direction in ["blocks", "blocked_by"] do
    {:noreply, assign(socket, :dependency_direction, direction)}
  end

  def set_dependency_direction(_params, socket), do: {:noreply, socket}

  def confirm_dependency(_params, socket) do
    active_ticket = find_active_ticket(socket)
    target_id = socket.assigns.selected_dependency_target
    direction = socket.assigns.dependency_direction

    cond do
      is_nil(active_ticket) ->
        {:noreply, put_flash(socket, :error, "No ticket selected")}

      is_nil(target_id) or is_nil(direction) ->
        {:noreply, put_flash(socket, :error, "Select a ticket and direction first")}

      true ->
        do_confirm_dependency(active_ticket, target_id, direction, socket)
    end
  end

  defp do_confirm_dependency(active_ticket, target_id, direction, socket) do
    user = socket.assigns.current_scope.user

    {blocker_id, blocked_id} =
      case direction do
        "blocks" -> {active_ticket.id, target_id}
        "blocked_by" -> {target_id, active_ticket.id}
      end

    case Tickets.add_dependency(blocker_id, blocked_id, actor_id: user.id) do
      {:ok, _dep} ->
        tickets = reload_tickets(socket)

        {:noreply,
         socket
         |> reset_dependency_assigns()
         |> assign(:tickets, tickets)
         |> put_flash(:info, "Dependency added")}

      {:error, error} ->
        {:noreply, put_flash(socket, :error, dependency_error_message(error))}
    end
  end

  defp dependency_error_message(:circular_dependency),
    do: "Cannot add dependency — it would create a circular chain"

  defp dependency_error_message(:duplicate_dependency),
    do: "This dependency already exists"

  defp dependency_error_message(:self_dependency),
    do: "A ticket cannot depend on itself"

  defp dependency_error_message(reason) do
    Logger.error("Failed to add dependency: #{inspect(reason)}")
    "Failed to add dependency"
  end

  def remove_dependency(%{"blocker-id" => blocker_str, "blocked-id" => blocked_str}, socket) do
    user = socket.assigns.current_scope.user

    with {blocker_id, ""} <- Integer.parse(blocker_str),
         {blocked_id, ""} <- Integer.parse(blocked_str) do
      case Tickets.remove_dependency(blocker_id, blocked_id, actor_id: user.id) do
        :ok ->
          tickets = reload_tickets(socket)

          {:noreply,
           socket
           |> assign(:tickets, tickets)
           |> put_flash(:info, "Dependency removed")}

        {:error, :dependency_not_found} ->
          {:noreply, put_flash(socket, :error, "Dependency not found")}
      end
    else
      _ -> {:noreply, socket}
    end
  end

  defp find_active_ticket(socket) do
    find_ticket_by_number(socket.assigns.tickets, socket.assigns.active_ticket_number)
  end

  defp reset_dependency_assigns(socket) do
    socket
    |> assign(:dependency_search_mode, false)
    |> assign(:dependency_search_results, [])
    |> assign(:dependency_search_query, "")
    |> assign(:selected_dependency_target, nil)
    |> assign(:dependency_direction, nil)
  end
end
