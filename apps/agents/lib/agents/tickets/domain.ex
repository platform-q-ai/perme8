defmodule Agents.Tickets.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Ticket,
      Entities.TicketLifecycleEvent,
      Entities.Ticket.View,
      Events.TicketCreated,
      Events.TicketDependencyChanged,
      Events.TicketStageChanged,
      Policies.TicketDependencyPolicy,
      Policies.TicketHierarchyPolicy,
      Policies.TicketEnrichmentPolicy,
      Policies.TicketLifecyclePolicy
    ]
end
