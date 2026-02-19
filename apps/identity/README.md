# Identity

Self-contained bounded context for user management, authentication, authorization, workspace multi-tenancy, and API key management. Serves its own Phoenix endpoint with LiveView pages for all auth flows.

## Architecture

Clean Architecture with strict layer enforcement via `mix boundary`:

```
Domain          Entities, Policies, Services (pure Elixir, zero deps)
Application     Use Cases, Behaviours (orchestration, ports)
Infrastructure  Ecto Schemas, Repositories, Queries, Notifiers
Interface       LiveViews, Controllers, Plugs, Endpoint
```

The `Identity` module (`lib/identity.ex`) is a **facade** -- a thin public API that delegates to use cases for complex operations and performs direct Repo queries for simple reads.

## Domain Model

### Entities

| Entity | Purpose |
|---|---|
| `User` | Core account: name, email, hashed password, role, status, preferences |
| `UserToken` | Auth tokens for sessions, magic links, email changes, password resets |
| `Workspace` | Multi-tenant workspace with name, slug, color, archived flag |
| `WorkspaceMember` | Membership join: email, role (owner/admin/member/guest), invite status |
| `ApiKey` | Hashed API token with name, description, workspace access list |

### Policies

| Policy | Purpose |
|---|---|
| `AuthenticationPolicy` | Sudo mode -- recent auth required for sensitive operations (20 min window) |
| `TokenPolicy` | Expiry rules: sessions 14d, magic links 15m, email changes 7d, password resets 1h |
| `ApiKeyPolicy` | Users can only manage their own keys |
| `MembershipPolicy` | Invitation role constraints, protected owner role |
| `WorkspacePermissionsPolicy` | RBAC matrix: guest/member (view), admin (manage), owner (full control) |

## Use Cases

### Authentication
- `RegisterUser` -- registration with password hashing
- `GenerateSessionToken` -- session token creation
- `DeliverLoginInstructions` -- magic link email
- `LoginByMagicLink` -- token-based login with auto-confirm
- `DeliverResetPasswordInstructions` -- password reset email
- `ResetUserPassword` -- token verification + password update

### Account Management
- `UpdateUserEmail` -- email change via token verification
- `UpdateUserPassword` -- password change with token expiry
- `DeliverUserUpdateEmailInstructions` -- email change verification

### API Keys
- `CreateApiKey` -- generate hashed token with workspace access
- `ListApiKeys` -- list with active/inactive filter
- `UpdateApiKey` -- update name, description, workspace access
- `RevokeApiKey` -- soft deactivation
- `VerifyApiKey` -- constant-time hash verification

### Workspace Membership
- `InviteMember` -- permission-checked invitation with email notification + domain event emission
- `ChangeMemberRole` -- role update with authorization
- `RemoveMember` -- member removal with authorization
- `CreateNotificationsForPendingInvitations` -- emits events on new user signup for pending invitations

## Routes

### Public (no auth required)

| Method | Path | Handler |
|---|---|---|
| GET | `/users/register` | `RegistrationLive` |
| GET | `/users/log-in` | `LoginLive` |
| POST | `/users/log-in` | `SessionController.create` |
| GET | `/users/log-in/:token` | `ConfirmationLive` |
| GET | `/users/reset-password` | `ForgotPasswordLive` |
| GET | `/users/reset-password/:token` | `ResetPasswordLive` |
| DELETE | `/users/log-out` | `SessionController.delete` |

### Authenticated (require login)

| Method | Path | Handler |
|---|---|---|
| POST | `/users/update-password` | `SessionController.update_password` |
| GET | `/users/settings` | `SettingsLive` (sudo mode) |
| GET | `/users/settings/confirm-email/:token` | `SettingsLive` |
| GET | `/users/settings/api-keys` | `ApiKeysLive` |

### Dev-only

- `/dev/dashboard` -- Phoenix LiveDashboard
- `/dev/mailbox` -- Swoosh mailbox preview

## Security

`SecurityHeadersPlug` is applied at the endpoint level (before routing) so every response -- including static files, redirects, and error pages -- carries these headers:

| Header | Value |
|---|---|
| `X-Content-Type-Options` | `nosniff` |
| `X-Frame-Options` | `DENY` |
| `Referrer-Policy` | `strict-origin-when-cross-origin` |
| `Content-Security-Policy` | Comprehensive policy with `frame-ancestors 'none'`, `form-action 'self'`, `base-uri 'self'`, `object-src 'none'` (LiveView requires `'unsafe-inline'` for script/style-src) |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains` |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=()` |

Additional security features:
- CSRF protection via Phoenix's `protect_from_forgery` plug + LiveView meta-tag tokens
- Bcrypt password hashing with timing-attack-resistant dummy verification
- Session token reissue after 7 days, remember-me cookie (14 days)
- API key authentication via `ApiAuthPlug` (Bearer token, constant-time verify)
- SHA256-hashed API key storage (plain token shown once at creation)

## Plugs

| Plug | Purpose |
|---|---|
| `UserAuth` | Session management, `fetch_current_scope_for_user`, `require_authenticated_user`, LiveView on_mount hooks for auth + sudo mode |
| `ApiAuthPlug` | Bearer token auth for API endpoints, returns 401 JSON on failure |
| `SecurityHeadersPlug` | Endpoint-level security headers on all responses |

## Testing

**493 unit tests** + **18 browser scenarios** + **58 security scenarios**

### Unit Tests (ExUnit)

```sh
# From umbrella root
mix test apps/identity/test/
```

Covers all layers: domain entities/policies/services, application use cases, infrastructure repos/queries/notifiers, web controllers/LiveViews/plugs. Uses Ecto sandbox for isolation and dependency injection on use cases for testability.

### Browser Tests (exo-bdd)

`test/features/identity.browser.feature` -- 18 Playwright-driven scenarios:
- Login page rendering and form submissions (magic link + password)
- Registration form, validation errors, successful registration
- Navigation flows between login/registration
- Forgot password and reset password flows

### Security Tests (exo-bdd + OWASP ZAP)

`test/features/identity.security.feature` -- 58 scenarios via ZAP Docker container:
- **Attack surface discovery** -- spidering all endpoints
- **Passive scanning** -- all pages checked for medium+ alerts (excluding known LiveView false positives: CSP `unsafe-inline`, anti-CSRF token format)
- **Active scanning** -- SQL injection, XSS (reflected + persistent), path traversal, remote code execution, CSRF on all auth endpoints
- **Security headers** -- CSP, HSTS, X-Frame-Options, X-Content-Type-Options, Referrer-Policy, Permissions-Policy verified on every page
- **Baseline scans** -- combined spider + passive for CI pipeline
- **Audit reports** -- HTML + JSON report generation

### Running exo-bdd Tests

```sh
# From umbrella root -- runs all exo-bdd configs (ERM + Identity)
mix exo_test

# Or directly via bun
cd tools/exo-bdd && bun run test -- --config ../../apps/identity/test/exo-bdd-identity.config.ts
```

The test runner automatically:
1. Starts Phoenix on port 4001 (`MIX_ENV=test`)
2. Seeds the database (`priv/repo/exo_seeds.exs`)
3. Launches ZAP Docker container on port 8080 (for security tests)
4. Launches headless Chromium (for browser tests)

## Perme8.Events.DomainEvent

This app hosts the `Perme8.Events.DomainEvent` macro (`lib/perme8_events/domain_event.ex`), which is the base macro for all domain event structs across the umbrella. It lives here (rather than in `jarga`) because `agents` depends on `identity` but cannot depend on `jarga` (cyclic dependency). The macro is defined as a standalone boundary with `check: [in: false]` so any module in any app can use it.

### Identity Domain Events

| Event | Aggregate | Emitted By |
|-------|-----------|------------|
| `MemberInvited` | `workspace_member` | `InviteMember` use case |
| `WorkspaceUpdated` | `workspace` | Identity facade |
| `MemberRemoved` | `workspace_member` | `RemoveMember` use case |
| `WorkspaceInvitationNotified` | `workspace_member` | `CreateNotificationsForPendingInvitations` use case |

## Umbrella Context

- **Endpoint**: `IdentityWeb.Endpoint` on port 4001 (configurable)
- **Database**: shares PostgreSQL with `jarga` app (migrations live in `apps/jarga/priv/repo/migrations/`)
- **Session**: shares cookie with `JargaWeb` (`_jarga_key`, same signing salt) for SSO
- **Dependencies**: Identity depends on no other umbrella apps at compile time. Runtime coupling to `Jarga.Workspaces` uses `Code.ensure_loaded?/1` + `apply/3` to avoid compile-time boundary violations
- **Exports**: domain entities, policies, services, and schemas used by other apps (e.g., `Jarga.AccountsFixtures`)

## Development

```sh
# Install dependencies
mix setup

# Start the server (from umbrella root)
mix phx.server
# Identity available at http://localhost:4001

# Run tests
mix test apps/identity/test/

# Check boundaries
mix boundary

# Compile with warnings as errors
mix compile --warnings-as-errors
```

Requires Docker for security tests (ZAP container) and Postgres running on `localhost:5432` (dev) / `localhost:5433` (test).
