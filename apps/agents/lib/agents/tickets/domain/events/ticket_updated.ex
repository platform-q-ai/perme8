defmodule Agents.Tickets.Domain.Events.TicketUpdated do
  @moduledoc """
  Domain event emitted when a ticket's fields are updated locally.

  Subscribers (e.g. GitHub push handlers) react to this event
  to synchronise changes with external systems.

  Fields:
    - `ticket_id` - The internal ID of the ticket
    - `number` - The ticket number (GitHub issue number or temp number)
    - `changes` - Map of field names to their new values
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [ticket_id: nil, number: nil, changes: %{}],
    required: [:ticket_id, :number]
end
