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
      Clients.GithubProjectClient,
      Schemas.ProjectTicketSchema,
      Schemas.TicketLifecycleEventSchema,
      Repositories.ProjectTicketRepository,
      Repositories.TicketLifecycleEventRepository,
      Subscribers.GithubTicketPushHandler,
      TicketSyncServer
    ]
end
