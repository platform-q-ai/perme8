defmodule Chat.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Chat context.
  """

  use Boundary,
    top_level?: true,
    deps: [Chat.Domain, Chat.Application, Chat.Repo],
    exports: [
      Schemas.SessionSchema,
      Schemas.MessageSchema,
      Repositories.SessionRepository,
      Repositories.MessageRepository,
      Queries.Queries
    ]
end
