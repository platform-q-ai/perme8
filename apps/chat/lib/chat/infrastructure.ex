defmodule Chat.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Chat context.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Domain, Chat.Application, Chat.Repo, Identity, Perme8.Events],
    exports: [
      Schemas.SessionSchema,
      Schemas.MessageSchema,
      Repositories.SessionRepository,
      Repositories.MessageRepository,
      Queries.Queries,
      Adapters.IdentityApiAdapter,
      Subscribers.IdentityEventSubscriber,
      Workers.OrphanDetectionWorker
    ]
end
