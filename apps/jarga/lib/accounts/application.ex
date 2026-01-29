defmodule Jarga.Accounts.Application do
  @moduledoc """
  Application layer boundary for the Accounts context.

  Contains orchestration logic that coordinates domain and infrastructure:

  ## Use Cases
  - `UseCases.RegisterUser` - User registration flow
  - `UseCases.LoginByMagicLink` - Magic link authentication
  - `UseCases.GenerateSessionToken` - Session token generation
  - `UseCases.UpdateUserPassword` - Password update flow
  - `UseCases.UpdateUserEmail` - Email change flow
  - `UseCases.DeliverLoginInstructions` - Send magic link email
  - `UseCases.DeliverUserUpdateEmailInstructions` - Send email verification
  - `UseCases.CreateApiKey` - API key creation
  - `UseCases.ListApiKeys` - List user's API keys
  - `UseCases.UpdateApiKey` - Update API key properties
  - `UseCases.RevokeApiKey` - Deactivate API key
  - `UseCases.VerifyApiKey` - Verify API key token
  - `UseCases.ListAccessibleWorkspaces` - List workspaces for API key
  - `UseCases.GetWorkspaceWithDetails` - Get workspace details via API
  - `UseCases.CreateProjectViaApi` - Create project via API
  - `UseCases.GetProjectWithDocumentsViaApi` - Get project with documents

  ## Services
  - `Services.PasswordService` - Password hashing and verification
  - `Services.ApiKeyTokenService` - API key token operations

  ## Dependency Rule

  The Application layer may only depend on:
  - Domain layer (same context)

  It cannot import:
  - Infrastructure layer (repos, schemas, notifiers)
  - Other contexts directly (use dependency injection)
  """

  use Boundary,
    top_level?: true,
    deps: [Jarga.Accounts.Domain],
    exports: [
      UseCases.RegisterUser,
      UseCases.LoginByMagicLink,
      UseCases.GenerateSessionToken,
      UseCases.UpdateUserPassword,
      UseCases.UpdateUserEmail,
      UseCases.DeliverLoginInstructions,
      UseCases.DeliverUserUpdateEmailInstructions,
      UseCases.CreateApiKey,
      UseCases.ListApiKeys,
      UseCases.UpdateApiKey,
      UseCases.RevokeApiKey,
      UseCases.VerifyApiKey,
      UseCases.ListAccessibleWorkspaces,
      UseCases.GetWorkspaceWithDetails,
      UseCases.CreateProjectViaApi,
      UseCases.GetProjectWithDocumentsViaApi,
      UseCases.UseCase,
      Services.PasswordService,
      Services.ApiKeyTokenService
    ]
end
