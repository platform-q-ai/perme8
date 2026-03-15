defmodule Agents.Tickets.Domain.Events.TicketDependencyChanged do
  @moduledoc """
  Domain event emitted when a ticket dependency relationship is added or removed.

  Fields:
    - `blocker_ticket_id` - The ticket that blocks another
    - `blocked_ticket_id` - The ticket that is blocked
    - `action` - `:added` or `:removed`
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [blocker_ticket_id: nil, blocked_ticket_id: nil, action: nil],
    required: [:blocker_ticket_id, :blocked_ticket_id, :action]
end
