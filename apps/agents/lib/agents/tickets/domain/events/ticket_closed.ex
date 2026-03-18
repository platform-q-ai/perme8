defmodule Agents.Tickets.Domain.Events.TicketClosed do
  @moduledoc """
  Domain event emitted when a ticket is closed locally.

  Subscribers (e.g. the GitHub push handler) react to this event
  to synchronise the close with external systems.

  Fields:
    - `ticket_id` - The internal ID of the ticket
    - `number` - The ticket number (GitHub issue number)
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [ticket_id: nil, number: nil],
    required: [:ticket_id, :number]
end
