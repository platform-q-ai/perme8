defmodule Agents.Tickets.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Tickets.Domain,
      Agents.Tickets.Application,
      Agents.Repo
    ],
    exports: [
      Schemas.ProjectTicketSchema,
      Repositories.ProjectTicketRepository,
      TicketSyncServer
    ]
end
