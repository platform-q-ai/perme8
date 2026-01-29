defmodule Jarga.Accounts.Domain do
  @moduledoc """
  Domain layer boundary for the Accounts context.

  Contains pure business logic with NO external dependencies:

  ## Entities
  - `Entities.User` - User domain entity (pure struct)
  - `Entities.ApiKey` - API key domain entity
  - `Entities.UserToken` - User token domain entity

  ## Policies (Business Rules)
  - `Policies.AuthenticationPolicy` - Authentication rules (sudo mode, etc.)
  - `Policies.TokenPolicy` - Token expiration and validity rules
  - `Policies.ApiKeyPolicy` - API key ownership and permissions
  - `Policies.WorkspaceAccessPolicy` - Workspace access validation

  ## Services (Pure Functions)
  - `Services.TokenBuilder` - Token construction logic

  ## Other
  - `Scope` - Authorization scope definition

  ## Dependency Rule

  The Domain layer has NO dependencies. It cannot import:
  - Application layer (use cases, services)
  - Infrastructure layer (repos, schemas, notifiers)
  - External libraries (Ecto, Phoenix, etc.)
  - Other contexts
  """

  use Boundary,
    top_level?: true,
    deps: [],
    exports: [
      Entities.User,
      Entities.ApiKey,
      Entities.UserToken,
      Policies.AuthenticationPolicy,
      Policies.TokenPolicy,
      Policies.ApiKeyPolicy,
      Policies.WorkspaceAccessPolicy,
      Services.TokenBuilder,
      Scope
    ]
end
