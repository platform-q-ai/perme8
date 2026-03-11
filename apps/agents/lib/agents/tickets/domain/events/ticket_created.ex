defmodule Agents.Tickets.Domain.Events.TicketCreated do
  @moduledoc """
  Domain event emitted when a ticket is created locally.

  Subscribers (e.g. the GitHub push handler) react to this event
  to synchronise the ticket with external systems.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [ticket_id: nil, title: nil, body: nil],
    required: [:ticket_id, :title]
end
