defmodule AgentsWeb.DashboardLive.Helpers.TicketDataHelpers do
  @moduledoc """
  Ticket tree operations and lookups for the dashboard LiveView.

  Pure functions for traversing, searching, and updating the hierarchical
  ticket data structure (tickets with sub_tickets). Also handles ticket
  number extraction and ticket-task ownership checks.
  """

  alias Agents.Tickets
  alias Agents.Tickets.Domain.Entities.Ticket

  def map_ticket_tree(tickets, fun) when is_list(tickets) do
    Enum.map(tickets, fn ticket ->
      updated = fun.(ticket)
      %{updated | sub_tickets: map_ticket_tree(updated.sub_tickets || [], fun)}
    end)
  end

  def all_tickets(tickets) when is_list(tickets) do
    Enum.flat_map(tickets, fn ticket -> [ticket | all_tickets(ticket.sub_tickets || [])] end)
  end

  def find_ticket_by_number(tickets, number) when is_integer(number) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.number == number))
  end

  def find_ticket_by_number(_tickets, _number), do: nil

  def update_ticket_by_number(tickets, number, update_fn) when is_list(tickets) do
    Enum.map(tickets, fn ticket ->
      cond do
        ticket.number == number ->
          update_fn.(ticket)

        is_list(ticket.sub_tickets) and ticket.sub_tickets != [] ->
          %{ticket | sub_tickets: update_ticket_by_number(ticket.sub_tickets, number, update_fn)}

        true ->
          ticket
      end
    end)
  end

  def lifecycle_ticket_match?(ticket, ticket_id) do
    candidate_ids = [Map.get(ticket, :id), Map.get(ticket, :number)]
    ticket_id in candidate_ids
  end

  def find_parent_ticket(_tickets, %{parent_ticket_id: nil}), do: nil

  def find_parent_ticket(tickets, %{parent_ticket_id: parent_id}) do
    tickets
    |> all_tickets()
    |> Enum.find(&(&1.id == parent_id))
  end

  def find_ticket_number_for_container(tickets, container_id) do
    case Enum.find(all_tickets(tickets), &(&1.associated_container_id == container_id)) do
      %{number: number} -> number
      _ -> nil
    end
  end

  def find_ticket_number_for_selected_session(sessions, tickets, container_id) do
    case find_ticket_number_for_container(tickets, container_id) do
      number when is_integer(number) ->
        number

      _ ->
        extract_ticket_number_from_session(sessions, tickets, container_id)
    end
  end

  def extract_ticket_number_from_session(sessions, tickets, container_id) do
    session = Enum.find(sessions, &(&1.container_id == container_id))
    title = is_map(session) && Map.get(session, :title)

    with title when is_binary(title) <- title,
         number when is_integer(number) and number > 0 <-
           Tickets.extract_ticket_number(title),
         true <- Enum.any?(all_tickets(tickets), &(&1.number == number)) do
      number
    else
      _ -> nil
    end
  end

  def next_active_ticket_number([], _current), do: nil

  def next_active_ticket_number(tickets, current) do
    flattened_tickets = all_tickets(tickets)

    case Enum.find(flattened_tickets, &(&1.number == current)) do
      %{number: number} -> number
      _ -> flattened_tickets |> List.first() |> then(&(&1 && &1.number))
    end
  end

  def resolve_container_for_ticket(nil, _tasks_snapshot), do: nil

  def resolve_container_for_ticket(ticket, tasks_snapshot) do
    case ticket.associated_container_id do
      cid when is_binary(cid) and cid != "" ->
        cid

      _ ->
        resolve_container_from_task_id(ticket.associated_task_id, tasks_snapshot)
    end
  end

  def resolve_container_from_task_id(nil, _tasks_snapshot), do: nil
  def resolve_container_from_task_id(_task_id, nil), do: nil
  def resolve_container_from_task_id(_task_id, tasks) when not is_list(tasks), do: nil

  def resolve_container_from_task_id(task_id, tasks_snapshot) do
    case Enum.find(tasks_snapshot, &(&1.id == task_id)) do
      nil -> nil
      task -> Map.get(task, :container_id)
    end
  end

  def ticket_owns_current_task?(nil, _current_task), do: false
  def ticket_owns_current_task?(_ticket, nil), do: false

  def ticket_owns_current_task?(%{associated_task_id: task_id}, %{id: current_id})
      when is_binary(task_id) and is_binary(current_id) do
    task_id == current_id
  end

  def ticket_owns_current_task?(_ticket, _current_task), do: false

  def ensure_ticket_reference(instruction, nil, _ticket), do: instruction

  def ensure_ticket_reference(instruction, _ticket_number, %Ticket{} = ticket) do
    context = Tickets.build_ticket_context(ticket)

    if Tickets.extract_ticket_number(instruction) do
      "#{instruction}\n\n#{context}"
    else
      "##{ticket.number} #{instruction}\n\n#{context}"
    end
  end

  def ensure_ticket_reference(instruction, ticket_number, nil) do
    if Tickets.extract_ticket_number(instruction) do
      instruction
    else
      "##{ticket_number} #{instruction}"
    end
  end

  def parse_ticket_number_param(%{"ticket_number" => value}) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} when number > 0 -> number
      _ -> nil
    end
  end

  def parse_ticket_number_param(_), do: nil
end
