defmodule Jarga.Accounts.Infrastructure do
  @moduledoc """
  Infrastructure layer boundary for the Accounts context.

  Contains implementations that interact with external systems:

  ## Schemas (Database Representation)
  - `Schemas.UserSchema` - Ecto schema for users table
  - `Schemas.UserTokenSchema` - Ecto schema for user tokens
  - `Schemas.ApiKeySchema` - Ecto schema for API keys

  ## Repositories (Data Access)
  - `Repositories.UserRepository` - User persistence operations
  - `Repositories.UserTokenRepository` - Token persistence operations
  - `Repositories.ApiKeyRepository` - API key persistence operations

  ## Queries (Ecto Query Builders)
  - `Queries.Queries` - General account queries
  - `Queries.ApiKeyQueries` - API key specific queries

  ## Notifiers (External Communication)
  - `Notifiers.UserNotifier` - Email notifications for users

  ## Services (External Integrations)
  - `Services.TokenGenerator` - Secure token generation

  ## Dependency Rule

  The Infrastructure layer may depend on:
  - Domain layer (for entities and policies)
  - Application layer (to implement service behaviours)
  - Shared infrastructure (Repo, Mailer)

  It can use external libraries (Ecto, Swoosh, etc.)
  """

  use Boundary,
    top_level?: true,
    deps: [
      Jarga.Accounts.Domain,
      Jarga.Accounts.Application,
      Jarga.Repo,
      Jarga.Mailer
    ],
    exports: [
      Schemas.UserSchema,
      Schemas.UserTokenSchema,
      Schemas.ApiKeySchema,
      Repositories.UserRepository,
      Repositories.UserTokenRepository,
      Repositories.ApiKeyRepository,
      Queries.Queries,
      Queries.ApiKeyQueries,
      Notifiers.UserNotifier,
      Services.TokenGenerator
    ]
end
