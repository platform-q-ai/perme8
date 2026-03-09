defmodule Agents.Tickets.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [Agents.Sessions.Domain],
    exports: [
      Entities.Ticket,
      Policies.TicketHierarchyPolicy,
      Policies.TicketEnrichmentPolicy
    ]
end
