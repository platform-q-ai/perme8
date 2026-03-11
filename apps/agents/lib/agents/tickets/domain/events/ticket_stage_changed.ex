defmodule Agents.Tickets.Domain.Events.TicketStageChanged do
  @moduledoc """
  Domain event emitted when a ticket lifecycle stage changes.
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [ticket_id: nil, from_stage: nil, to_stage: nil, trigger: "system"],
    required: [:ticket_id, :from_stage, :to_stage]
end
