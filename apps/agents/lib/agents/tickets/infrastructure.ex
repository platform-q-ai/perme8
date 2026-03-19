defmodule Agents.Tickets.Infrastructure do
  @moduledoc false

  use Boundary,
    top_level?: true,
    deps: [
      Agents.Tickets.Domain,
      Agents.Tickets.Application,
      Agents.Application,
      Agents.Repo
    ],
    exports: [
      Clients.GithubProjectClient,
      Queries.AnalyticsQueries,
      Schemas.ProjectTicketSchema,
      Schemas.TicketDependencySchema,
      Schemas.TicketLifecycleEventSchema,
      Repositories.AnalyticsRepository,
      Repositories.ProjectTicketRepository,
      Repositories.TicketDependencyRepository,
      Repositories.TicketLifecycleEventRepository,
      Subscribers.GithubTicketPushHandler,
      TicketSyncServer
    ]
end
