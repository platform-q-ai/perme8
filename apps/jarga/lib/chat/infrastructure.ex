defmodule Jarga.Chat.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Chat context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.SessionSchema` - Ecto schema for chat_sessions table
  - `Schemas.MessageSchema` - Ecto schema for chat_messages table

  ## Repositories (Data Access)
  - `Repositories.SessionRepository` - Session persistence operations
  - `Repositories.MessageRepository` - Message persistence operations

  ## Queries (Ecto Query Builders)
  - `Queries.Queries` - Chat-related database queries

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities)
  - Application layer (to implement service behaviours)
  - Shared infrastructure (Repo)

  It can use external libraries (Ecto, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Chat.Domain,
      Jarga.Chat.Application,
      Jarga.Repo
    ],
    exports: [
      Schemas.SessionSchema,
      Schemas.MessageSchema,
      Repositories.SessionRepository,
      Repositories.MessageRepository,
      Queries.Queries
    ]
end
