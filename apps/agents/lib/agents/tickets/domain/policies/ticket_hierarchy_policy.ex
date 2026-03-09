defmodule Agents.Tickets.Domain.Policies.TicketHierarchyPolicy do
  @moduledoc """
  Pure hierarchy rules for ticket parent/child relationships.
  """

  alias Agents.Tickets.Domain.Entities.Ticket

  @spec build_tree([Ticket.t()]) :: [Ticket.t()]
  def build_tree(tickets) when is_list(tickets) do
    tickets_by_parent = Enum.group_by(tickets, & &1.parent_ticket_id)
    ids = MapSet.new(tickets, & &1.id)

    root_tickets =
      Enum.filter(tickets, fn ticket ->
        is_nil(ticket.parent_ticket_id) or not MapSet.member?(ids, ticket.parent_ticket_id)
      end)

    Enum.map(root_tickets, &attach_sub_tickets(&1, tickets_by_parent))
  end

  @spec circular_reference?([Ticket.t()], {integer() | nil, integer() | nil}) :: boolean()
  def circular_reference?(_tickets, {_child_id, nil}), do: false

  def circular_reference?(tickets, {child_id, parent_id}) do
    parent_by_id = Map.new(tickets, &{&1.id, &1.parent_ticket_id})
    detects_cycle?(parent_by_id, child_id, parent_id)
  end

  @spec sub_ticket_summary(Ticket.t()) :: {non_neg_integer(), non_neg_integer()}
  def sub_ticket_summary(%Ticket{sub_tickets: sub_tickets}) when is_list(sub_tickets) do
    closed_count = Enum.count(sub_tickets, &Ticket.closed?/1)
    {closed_count, length(sub_tickets)}
  end

  def sub_ticket_summary(_), do: {0, 0}

  @spec sub_ticket_summary_text(Ticket.t()) :: String.t()
  def sub_ticket_summary_text(ticket) do
    {closed_count, total_count} = sub_ticket_summary(ticket)

    if closed_count > 0 do
      "#{closed_count}/#{total_count} closed"
    else
      "#{total_count} sub-issues"
    end
  end

  @spec max_depth() :: integer()
  def max_depth, do: 2

  defp attach_sub_tickets(ticket, tickets_by_parent) do
    sub_tickets =
      Map.get(tickets_by_parent, ticket.id, [])
      |> Enum.map(&attach_sub_tickets(&1, tickets_by_parent))

    %{ticket | sub_tickets: sub_tickets}
  end

  defp detects_cycle?(_parent_by_id, child_id, child_id), do: true
  defp detects_cycle?(_parent_by_id, _child_id, nil), do: false

  defp detects_cycle?(parent_by_id, child_id, current_parent_id) do
    case Map.get(parent_by_id, current_parent_id) do
      nil -> false
      next_parent_id -> detects_cycle?(parent_by_id, child_id, next_parent_id)
    end
  end
end
