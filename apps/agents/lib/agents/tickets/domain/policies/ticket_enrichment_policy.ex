defmodule Agents.Tickets.Domain.Policies.TicketEnrichmentPolicy do
  @moduledoc """
  Pure enrichment logic for linking tickets to session tasks.

  Uses two strategies to find the matching task for a ticket:
  1. **Persisted association** -- looks up the task by the ticket's stored
     `associated_task_id` (set when a task is created for a ticket).
  2. **Regex fallback** -- scans task instructions for `#N` or `ticket N`
     patterns and matches by ticket number.

  The persisted association takes priority so the link survives across
  page reloads, re-enrichment cycles, and ticket syncs.
  """

  alias Agents.Sessions.Domain.Policies.SessionLifecyclePolicy
  alias Agents.Tickets.Domain.Entities.Ticket

  @ticket_number_regex ~r/(?:^|\s)(?:#|ticket\s+)(\d+)\b/i

  @spec enrich(Ticket.t(), [map()]) :: Ticket.t()
  def enrich(%Ticket{} = ticket, tasks) when is_list(tasks) do
    task_by_ticket_number = build_task_index(tasks)
    task_by_id = build_task_id_index(tasks)
    resolve_and_apply(ticket, task_by_id, task_by_ticket_number)
  end

  def enrich(%Ticket{} = ticket, _tasks), do: ticket

  @spec enrich_all([Ticket.t()], [map()]) :: [Ticket.t()]
  def enrich_all(tickets, tasks) when is_list(tickets) and is_list(tasks) do
    task_by_ticket_number = build_task_index(tasks)
    task_by_id = build_task_id_index(tasks)
    Enum.map(tickets, &enrich_ticket_tree(&1, task_by_id, task_by_ticket_number))
  end

  def enrich_all(tickets, _tasks), do: tickets

  @spec extract_ticket_number(term()) :: integer() | nil
  def extract_ticket_number(instruction) when is_binary(instruction) do
    case Regex.run(@ticket_number_regex, instruction) do
      [_, value] -> String.to_integer(value)
      _ -> nil
    end
  end

  def extract_ticket_number(_), do: nil

  defp enrich_ticket_tree(%Ticket{} = ticket, task_by_id, task_by_ticket_number) do
    enriched = resolve_and_apply(ticket, task_by_id, task_by_ticket_number)

    %{
      enriched
      | sub_tickets:
          Enum.map(
            enriched.sub_tickets || [],
            &enrich_ticket_tree(&1, task_by_id, task_by_ticket_number)
          )
    }
  end

  defp resolve_and_apply(ticket, task_by_id, task_by_ticket_number) do
    task = resolve_task(ticket, task_by_id, task_by_ticket_number)
    apply_enrichment(ticket, task)
  end

  defp resolve_task(%Ticket{associated_task_id: task_id}, task_by_id, _task_by_ticket_number)
       when is_binary(task_id) and task_id != "" do
    Map.get(task_by_id, task_id)
  end

  defp resolve_task(%Ticket{number: number}, _task_by_id, task_by_ticket_number) do
    Map.get(task_by_ticket_number, number)
  end

  defp build_task_index(tasks) do
    Enum.reduce(tasks, %{}, fn task, acc ->
      case extract_ticket_number(task.instruction) do
        nil -> acc
        number -> Map.put_new(acc, number, task)
      end
    end)
  end

  defp build_task_id_index(tasks) do
    Map.new(tasks, fn task -> {Map.get(task, :id), task} end)
  end

  defp apply_enrichment(%Ticket{} = ticket, nil) do
    %{
      ticket
      | associated_task_id: nil,
        associated_container_id: nil,
        session_state: "idle",
        task_status: nil,
        task_error: nil
    }
  end

  defp apply_enrichment(%Ticket{} = ticket, task) do
    status = Map.get(task, :status)

    lifecycle_state =
      SessionLifecyclePolicy.derive(%{
        status: status,
        container_id: Map.get(task, :container_id),
        container_port: Map.get(task, :container_port)
      })

    %{
      ticket
      | associated_task_id: Map.get(task, :id),
        associated_container_id: Map.get(task, :container_id),
        session_state: Atom.to_string(lifecycle_state),
        task_status: status,
        task_error: Map.get(task, :error)
    }
  end
end
