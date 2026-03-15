defmodule Agents.Tickets.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Tickets.Domain, Perme8.Events],
    exports: [
      TicketsConfig,
      UseCases.AddTicketDependency,
      UseCases.CreateTicket,
      UseCases.RecordStageTransition,
      UseCases.RemoveTicketDependency
    ]
end
