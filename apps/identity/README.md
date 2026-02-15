# Identity

Self-contained authentication and identity management app for the Perme8 platform. Handles user registration, login (password and magic link), session management, API key management, password reset, and email verification. Runs its own Phoenix endpoint on port 4001.

## Architecture

Identity follows Clean Architecture with compile-time boundary enforcement:

```
Interface (LiveViews, Plugs, Controllers, Router)
    |
Application (Use Cases, Services, Behaviours)
    |
Domain (Entities, Policies, Services)
    |
Infrastructure (Ecto Schemas, Repositories, Queries, Notifiers)
```

### Domain Layer

| Module | Description |
|--------|-------------|
| `User` | User entity with email, hashed password, and confirmation fields |
| `UserToken` | Token entity for sessions, email verification, and password reset |
| `ApiKey` | API key entity with name, scoped permissions, and revocation support |
| `Authentication` | Policy enforcing authentication rules |
| `TokenPolicy` | Policy for token generation and validation |
| `ApiKeyPolicy` | Policy for API key validation rules |
| `TokenBuilder` | Service for building token structs |

### Application Layer

14 use cases covering the full authentication lifecycle:

| Use Case | Description |
|----------|-------------|
| `RegisterUser` | Create a new user account |
| `LoginByMagicLink` | Passwordless authentication via email link |
| `GenerateSessionToken` | Create a session token for an authenticated user |
| `DeliverLoginInstructions` | Send magic link login email |
| `UpdateUserPassword` | Change password for an authenticated user |
| `UpdateUserEmail` | Initiate email change with verification |
| `DeliverUserUpdateEmailInstructions` | Send email change verification |
| `DeliverResetPasswordInstructions` | Send password reset email |
| `ResetUserPassword` | Reset password using a valid token |
| `CreateApiKey` | Generate a new API key |
| `ListApiKeys` | List all API keys for a user |
| `UpdateApiKey` | Update API key name or scopes |
| `RevokeApiKey` | Revoke an API key |
| `VerifyApiKey` | Verify an API key token and return the associated user |

Services: `PasswordService`, `ApiKeyTokenService`

### Infrastructure Layer

| Module | Description |
|--------|-------------|
| `UserSchema` | Ecto schema for the `users` table |
| `UserTokenSchema` | Ecto schema for the `users_tokens` table |
| `ApiKeySchema` | Ecto schema for the `api_keys` table |
| `UserRepository` | User CRUD operations |
| `UserTokenRepository` | Token persistence and lookup |
| `ApiKeyRepository` | API key persistence and lookup |
| `TokenGenerator` | Cryptographic token generation |
| `UserNotifier` | Email delivery via Swoosh |

### Interface Layer

| Module | Description |
|--------|-------------|
| `IdentityWeb.Endpoint` | Phoenix endpoint (port 4001 dev, 4003 test) |
| `IdentityWeb.Router` | Routes for auth pages and API key management |
| `UserAuth` plug | Session-based authentication plug |
| `ApiAuthPlug` | Bearer token API authentication plug |
| LiveViews | Login, Registration, Settings, Confirmation, ForgotPassword, ResetPassword, ApiKeys |

## Database

Identity owns its own `Identity.Repo` backed by PostgreSQL with three tables:

- `users` -- email, hashed_password, confirmed_at
- `users_tokens` -- token, context, sent_to, user_id
- `api_keys` -- name, hashed_token, scopes, revoked_at, user_id

## Cross-App Exports

Identity exports its domain entities, policies, token services, and Ecto schemas so other umbrella apps (e.g., `jarga`, `jarga_api`) can verify API keys, resolve users, and create test fixtures.

## Running

```bash
# Start the identity endpoint standalone
mix phx.server

# Or within IEx
iex -S mix phx.server
```

Visit [`localhost:4001`](http://localhost:4001) for the identity web interface.

## Testing

```bash
# Run identity tests
mix test apps/identity/test

# Run a specific test file
mix test apps/identity/test/identity/application/use_cases/register_user_test.exs
```
