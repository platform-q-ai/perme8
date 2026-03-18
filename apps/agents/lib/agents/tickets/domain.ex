defmodule Agents.Tickets.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.AnalyticsView,
      Entities.Ticket,
      Entities.TicketLifecycleEvent,
      Entities.Ticket.View,
      Events.TicketClosed,
      Events.TicketCreated,
      Events.TicketDependencyChanged,
      Events.TicketStageChanged,
      Events.TicketSubIssueChanged,
      Events.TicketUpdated,
      Policies.AnalyticsPolicy,
      Policies.TicketDependencyPolicy,
      Policies.TicketHierarchyPolicy,
      Policies.TicketEnrichmentPolicy,
      Policies.TicketLifecyclePolicy
    ]
end
