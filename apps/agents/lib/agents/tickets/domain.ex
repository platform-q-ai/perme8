defmodule Agents.Tickets.Domain do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.Ticket,
      Policies.TicketHierarchyPolicy,
      Policies.TicketEnrichmentPolicy
    ]
end
