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
      Policies.TicketHierarchyPolicy,
      Policies.TicketEnrichmentPolicy,
      Policies.TicketLifecyclePolicy,
      Events.TicketStageChanged
    ]
end
