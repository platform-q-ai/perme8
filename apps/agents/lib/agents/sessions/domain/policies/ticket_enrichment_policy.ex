defmodule Agents.Sessions.Domain.Policies.TicketEnrichmentPolicy do
  @moduledoc """
  Pure enrichment logic for linking tickets to session tasks.
  """

  alias Agents.Sessions.Domain.Entities.Ticket

  @ticket_number_regex ~r/(?:^|\s)(?:#|ticket\s+)(\d+)\b/i

  @spec enrich(Ticket.t(), [map()]) :: Ticket.t()
  def enrich(%Ticket{} = ticket, tasks) when is_list(tasks) do
    task_by_ticket_number = build_task_index(tasks)
    apply_enrichment(ticket, Map.get(task_by_ticket_number, ticket.number))
  end

  def enrich(%Ticket{} = ticket, _tasks), do: ticket

  @spec enrich_all([Ticket.t()], [map()]) :: [Ticket.t()]
  def enrich_all(tickets, tasks) when is_list(tickets) and is_list(tasks) do
    task_by_ticket_number = build_task_index(tasks)
    Enum.map(tickets, &enrich_ticket_tree(&1, task_by_ticket_number))
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

  defp enrich_ticket_tree(%Ticket{} = ticket, task_by_ticket_number) do
    task = Map.get(task_by_ticket_number, ticket.number)

    enriched = apply_enrichment(ticket, task)

    %{
      enriched
      | sub_tickets:
          Enum.map(enriched.sub_tickets || [], &enrich_ticket_tree(&1, task_by_ticket_number))
    }
  end

  defp build_task_index(tasks) do
    Enum.reduce(tasks, %{}, fn task, acc ->
      case extract_ticket_number(task.instruction) do
        nil -> acc
        number -> Map.put_new(acc, number, task)
      end
    end)
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

    %{
      ticket
      | associated_task_id: Map.get(task, :id),
        associated_container_id: Map.get(task, :container_id),
        session_state: task_status_to_session_state(status),
        task_status: status,
        task_error: Map.get(task, :error)
    }
  end

  defp task_status_to_session_state(nil), do: "idle"

  defp task_status_to_session_state(status)
       when status in ["pending", "starting", "running", "queued", "awaiting_feedback"],
       do: "running"

  defp task_status_to_session_state("completed"), do: "completed"
  defp task_status_to_session_state(_), do: "paused"
end
