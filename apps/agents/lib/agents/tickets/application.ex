defmodule Agents.Tickets.Application do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Tickets.Domain, Perme8.Events],
    exports: [
      Behaviours.ProjectTicketRepositoryBehaviour,
      TicketsConfig,
      UseCases.AddSubIssue,
      UseCases.AddTicketDependency,
      UseCases.CloseTicket,
      UseCases.CreateTicket,
      UseCases.GetAnalytics,
      UseCases.RecordStageTransition,
      UseCases.RemoveSubIssue,
      UseCases.RemoveTicketDependency,
      UseCases.UpdateTicket
    ]
end
