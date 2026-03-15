defmodule Agents.Tickets.Domain.Events.TicketSubIssueChanged do
  @moduledoc """
  Domain event emitted when a sub-issue relationship is added or removed.

  Fields:
    - `parent_number` - The parent ticket number
    - `child_number` - The child ticket number
    - `action` - `:added` or `:removed`
  """

  use Perme8.Events.DomainEvent,
    aggregate_type: "ticket",
    fields: [parent_number: nil, child_number: nil, action: nil],
    required: [:parent_number, :child_number, :action]
end
