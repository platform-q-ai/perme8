# Refactoring Spec: Extract User Management into Identity App

## Overview

This spec defines the refactoring of user management functionality from `jarga_web` and `jarga` into a new dedicated umbrella app called `identity`. This consolidates all authentication, authorization, session management, and API key functionality into a single cohesive application.

## Goals

1. **Single Responsibility**: Create a dedicated app for all identity-related concerns
2. **Clean Boundaries**: Establish clear interfaces between identity and other apps
3. **Self-Contained**: Include both domain logic AND web interface in one app
4. **Maintainability**: Simplify reasoning about authentication/authorization code

## New App: `identity`

### App Type

Phoenix application with its own endpoint, web layer, and domain layers:

```bash
cd apps
mix phx.new identity --no-ecto --no-assets
```

> Note: 
> - `--no-ecto` because Ecto/Repo configuration remains in `jarga` initially (migrated to `Identity.Repo` in Phase 7)
> - `--no-assets` because identity uses jarga_web's assets (or minimal inline styles)
> - Mailer is included because identity sends registration, login, and email verification emails via `UserNotifier`
> - Identity has its own `IdentityWeb.Endpoint` that serves authentication routes directly

### Module Namespace

- `Identity` - Root module
- `Identity.Domain` - Domain layer (entities, policies, services)
- `Identity.Application` - Application layer (use cases, behaviours)
- `Identity.Infrastructure` - Infrastructure layer (repositories, schemas, notifiers)
- `IdentityWeb` - Web layer (LiveViews, plugs, controllers)

---

## Files to Move

### From `apps/jarga_web/` to `apps/identity/`

#### LiveViews → `lib/identity_web/live/`

| Source | Destination |
|--------|-------------|
| `lib/live/user_live/login.ex` | `lib/identity_web/live/login_live.ex` |
| `lib/live/user_live/registration.ex` | `lib/identity_web/live/registration_live.ex` |
| `lib/live/user_live/settings.ex` | `lib/identity_web/live/settings_live.ex` |
| `lib/live/user_live/confirmation.ex` | `lib/identity_web/live/confirmation_live.ex` |
| `lib/live/api_keys_live.ex` | `lib/identity_web/live/api_keys_live.ex` |

#### Plugs → `lib/identity_web/plugs/`

| Source | Destination |
|--------|-------------|
| `lib/user_auth.ex` | `lib/identity_web/plugs/user_auth.ex` |
| `lib/plugs/api_auth_plug.ex` | `lib/identity_web/plugs/api_auth_plug.ex` |

#### Controllers → `lib/identity_web/controllers/`

| Source | Destination |
|--------|-------------|
| `lib/controllers/user_session_controller.ex` | `lib/identity_web/controllers/session_controller.ex` |

#### Tests → `apps/identity/test/`

| Source | Destination |
|--------|-------------|
| `test/live/user_live/login_test.exs` | `test/identity_web/live/login_live_test.exs` |
| `test/live/user_live/registration_test.exs` | `test/identity_web/live/registration_live_test.exs` |
| `test/live/user_live/settings_test.exs` | `test/identity_web/live/settings_live_test.exs` |
| `test/live/user_live/confirmation_test.exs` | `test/identity_web/live/confirmation_live_test.exs` |
| `test/plugs/api_auth_plug_test.exs` | `test/identity_web/plugs/api_auth_plug_test.exs` |
| `test/user_auth_test.exs` | `test/identity_web/plugs/user_auth_test.exs` |

#### BDD Features → `apps/identity/test/features/`

| Source | Destination |
|--------|-------------|
| `test/features/accounts/authentication.feature` | `test/features/authentication.feature` |
| `test/features/accounts/email.feature` | `test/features/email.feature` |
| `test/features/accounts/password.feature` | `test/features/password.feature` |
| `test/features/accounts/registration.feature` | `test/features/registration.feature` |
| `test/features/accounts/sessions.feature` | `test/features/sessions.feature` |

---

### From `apps/jarga/` to `apps/identity/`

#### Domain Layer → `lib/identity/domain/`

| Source | Destination |
|--------|-------------|
| `lib/accounts/domain/entities/user.ex` | `lib/identity/domain/entities/user.ex` |
| `lib/accounts/domain/entities/user_token.ex` | `lib/identity/domain/entities/user_token.ex` |
| `lib/accounts/domain/entities/api_key.ex` | `lib/identity/domain/entities/api_key.ex` |
| `lib/accounts/domain/policies/authentication_policy.ex` | `lib/identity/domain/policies/authentication_policy.ex` |
| `lib/accounts/domain/policies/api_key_policy.ex` | `lib/identity/domain/policies/api_key_policy.ex` |
| `lib/accounts/domain/policies/workspace_access_policy.ex` | `lib/identity/domain/policies/workspace_access_policy.ex` |
| `lib/accounts/domain/services/token_builder.ex` | `lib/identity/domain/services/token_builder.ex` |
| `lib/accounts/domain/scope.ex` | `lib/identity/domain/scope.ex` |

#### Application Layer → `lib/identity/application/`

**Use Cases:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/application/use_cases/register_user.ex` | `lib/identity/application/use_cases/register_user.ex` |
| `lib/accounts/application/use_cases/login_by_magic_link.ex` | `lib/identity/application/use_cases/login_by_magic_link.ex` |
| `lib/accounts/application/use_cases/generate_session_token.ex` | `lib/identity/application/use_cases/generate_session_token.ex` |
| `lib/accounts/application/use_cases/deliver_login_instructions.ex` | `lib/identity/application/use_cases/deliver_login_instructions.ex` |
| `lib/accounts/application/use_cases/update_user_password.ex` | `lib/identity/application/use_cases/update_user_password.ex` |
| `lib/accounts/application/use_cases/update_user_email.ex` | `lib/identity/application/use_cases/update_user_email.ex` |
| `lib/accounts/application/use_cases/deliver_user_update_email_instructions.ex` | `lib/identity/application/use_cases/deliver_user_update_email_instructions.ex` |
| `lib/accounts/application/use_cases/create_api_key.ex` | `lib/identity/application/use_cases/create_api_key.ex` |
| `lib/accounts/application/use_cases/list_api_keys.ex` | `lib/identity/application/use_cases/list_api_keys.ex` |
| `lib/accounts/application/use_cases/update_api_key.ex` | `lib/identity/application/use_cases/update_api_key.ex` |
| `lib/accounts/application/use_cases/revoke_api_key.ex` | `lib/identity/application/use_cases/revoke_api_key.ex` |
| `lib/accounts/application/use_cases/verify_api_key.ex` | `lib/identity/application/use_cases/verify_api_key.ex` |

**Use Cases Remaining in `jarga`** (cross domain boundaries):

| File | Reason |
|------|--------|
| `lib/accounts/application/use_cases/list_accessible_workspaces.ex` | Crosses into workspace domain |
| `lib/accounts/application/use_cases/get_workspace_with_details.ex` | Crosses into workspace domain |
| `lib/accounts/application/use_cases/create_project_via_api.ex` | Crosses into project domain |
| `lib/accounts/application/use_cases/get_project_with_documents_via_api.ex` | Crosses into project/document domains |

**Services:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/application/services/password_service.ex` | `lib/identity/application/services/password_service.ex` |
| `lib/accounts/application/services/api_key_token_service.ex` | `lib/identity/application/services/api_key_token_service.ex` |

**Behaviours:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/application/behaviours/user_repository_behaviour.ex` | `lib/identity/application/behaviours/user_repository_behaviour.ex` |
| `lib/accounts/application/behaviours/user_token_repository_behaviour.ex` | `lib/identity/application/behaviours/user_token_repository_behaviour.ex` |
| `lib/accounts/application/behaviours/user_schema_behaviour.ex` | `lib/identity/application/behaviours/user_schema_behaviour.ex` |
| `lib/accounts/application/behaviours/user_notifier_behaviour.ex` | `lib/identity/application/behaviours/user_notifier_behaviour.ex` |
| `lib/accounts/application/behaviours/api_key_repository_behaviour.ex` | `lib/identity/application/behaviours/api_key_repository_behaviour.ex` |

#### Infrastructure Layer → `lib/identity/infrastructure/`

**Schemas:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/infrastructure/schemas/user_schema.ex` | `lib/identity/infrastructure/schemas/user_schema.ex` |
| `lib/accounts/infrastructure/schemas/user_token_schema.ex` | `lib/identity/infrastructure/schemas/user_token_schema.ex` |
| `lib/accounts/infrastructure/schemas/api_key_schema.ex` | `lib/identity/infrastructure/schemas/api_key_schema.ex` |

**Repositories:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/infrastructure/repositories/user_repository.ex` | `lib/identity/infrastructure/repositories/user_repository.ex` |
| `lib/accounts/infrastructure/repositories/user_token_repository.ex` | `lib/identity/infrastructure/repositories/user_token_repository.ex` |
| `lib/accounts/infrastructure/repositories/api_key_repository.ex` | `lib/identity/infrastructure/repositories/api_key_repository.ex` |

**Queries:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/infrastructure/queries/queries.ex` | `lib/identity/infrastructure/queries/token_queries.ex` |
| `lib/accounts/infrastructure/queries/api_key_queries.ex` | `lib/identity/infrastructure/queries/api_key_queries.ex` |

**Services:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/infrastructure/services/token_generator.ex` | `lib/identity/infrastructure/services/token_generator.ex` |

**Notifiers:**

| Source | Destination |
|--------|-------------|
| `lib/accounts/infrastructure/notifiers/user_notifier.ex` | `lib/identity/infrastructure/notifiers/user_notifier.ex` |

#### Facade → `lib/identity.ex`

| Source | Destination |
|--------|-------------|
| `lib/accounts.ex` | `lib/identity.ex` |

---

## New Directory Structure

```
apps/identity/
  lib/
    identity.ex                           # Public API facade
    identity/
      domain/
        entities/
          user.ex
          user_token.ex
          api_key.ex
        policies/
          authentication_policy.ex
          api_key_policy.ex
          workspace_access_policy.ex
        services/
          token_builder.ex
        scope.ex
      application/
        behaviours/
          user_repository_behaviour.ex
          user_token_repository_behaviour.ex
          user_schema_behaviour.ex
          user_notifier_behaviour.ex
          api_key_repository_behaviour.ex
        services/
          password_service.ex
          api_key_token_service.ex
        use_cases/
          register_user.ex
          login_by_magic_link.ex
          generate_session_token.ex
          deliver_login_instructions.ex
          update_user_password.ex
          update_user_email.ex
          deliver_user_update_email_instructions.ex
          create_api_key.ex
          list_api_keys.ex
          update_api_key.ex
          revoke_api_key.ex
          verify_api_key.ex
      infrastructure/
        schemas/
          user_schema.ex
          user_token_schema.ex
          api_key_schema.ex
        repositories/
          user_repository.ex
          user_token_repository.ex
          api_key_repository.ex
        queries/
          token_queries.ex
          api_key_queries.ex
        services/
          token_generator.ex
        notifiers/
          user_notifier.ex
    identity_web.ex                        # Web module with helpers
    identity_web/
      endpoint.ex                          # IdentityWeb.Endpoint
      router.ex                            # Identity routes
      telemetry.ex                         # Telemetry for identity endpoint
      plugs/
        user_auth.ex
        api_auth_plug.ex
      controllers/
        session_controller.ex
      live/
        login_live.ex
        registration_live.ex
        settings_live.ex
        confirmation_live.ex
        api_keys_live.ex
      components/
        layouts.ex                         # Layout components
        layouts/
          root.html.heex
          app.html.heex
        core_components.ex                 # Shared UI components
  test/
    identity/
      domain/
      application/
      infrastructure/
    identity_web/
      live/
      plugs/
      controllers/
    features/
      authentication.feature
      email.feature
      password.feature
      registration.feature
      sessions.feature
    test_helper.exs
  mix.exs
```

---

## Dependency Graph

```
                    +-----------+
                    |  jarga    |
                    | (domain)  |
                    +-----+-----+
                          ^
                          |
          +---------------+---------------+
          |                               |
    +-----+-----+                   +-----+-----+
    | identity  |                   | jarga_web |
    | (users,   |                   | (other    |
    |  auth,    |                   |  features)|
    |  api keys)|                   +-----------+
    +-----------+
```

### Dependencies in `apps/identity/mix.exs`

```elixir
defp deps do
  [
    {:jarga, in_umbrella: true},        # For Repo access, workspaces, projects
    {:phoenix, "~> 1.8"},
    {:phoenix_html, "~> 4.0"},
    {:phoenix_live_view, "~> 1.0"},
    {:phoenix_live_reload, "~> 1.5", only: :dev},
    {:bcrypt_elixir, "~> 3.0"},         # Password hashing
    {:swoosh, "~> 1.5"},                # Email delivery
    {:bandit, "~> 1.5"},                # HTTP server
    {:gettext, "~> 1.0"},               # Internationalization
    {:jason, "~> 1.2"},                 # JSON parsing
    # ... other deps
  ]
end
```

### Endpoint Configuration

**In `config/config.exs`:**

```elixir
# Identity endpoint configuration
config :identity, IdentityWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: IdentityWeb.ErrorHTML, json: IdentityWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Jarga.PubSub,  # Shared PubSub with jarga_web
  live_view: [signing_salt: "identity_lv_salt"]

# Shared session configuration
config :identity, :session_options,
  store: :cookie,
  key: "_jarga_key",
  signing_salt: "shared_session_salt",
  same_site: "Lax"
```

**In `config/dev.exs`:**

```elixir
config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4001],  # Different port from jarga_web
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "dev_secret_key_base_for_identity",
  watchers: []

config :identity, IdentityWeb.Endpoint,
  live_reload: [
    patterns: [
      ~r"priv/gettext/.*(po)$",
      ~r"lib/identity_web/(controllers|live|components)/.*(ex|heex)$"
    ]
  ]
```

**In `config/test.exs`:**

```elixir
config :identity, IdentityWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4003],  # Different port for tests
  secret_key_base: "test_secret_key_base_for_identity",
  server: true  # Start server for feature tests
```

### Dependencies in `apps/jarga_web/mix.exs`

Add identity as a dependency:

```elixir
defp deps do
  [
    {:identity, in_umbrella: true},  # For auth plugs, scope
    # ... existing deps
  ]
end
```

---

## Router Integration

### Identity App Owns Its Routes

The identity app has its own `IdentityWeb.Endpoint` and `IdentityWeb.Router`. Routes are served directly by the identity endpoint, not forwarded from jarga_web.

**In `apps/identity/lib/identity_web/router.ex`:**

```elixir
defmodule IdentityWeb.Router do
  use IdentityWeb, :router

  import IdentityWeb.Plugs.UserAuth

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {IdentityWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :fetch_current_scope_for_user
  end

  # Public routes (login, registration)
  scope "/", IdentityWeb do
    pipe_through [:browser]

    live_session :current_user,
      on_mount: [{IdentityWeb.Plugs.UserAuth, :mount_current_scope}] do
      live "/users/register", RegistrationLive, :new
      live "/users/log-in", LoginLive, :new
      live "/users/log-in/:token", ConfirmationLive, :new
    end

    post "/users/log-in", SessionController, :create
    delete "/users/log-out", SessionController, :delete
  end

  # Authenticated routes (settings, api keys)
  scope "/", IdentityWeb do
    pipe_through [:browser, :require_authenticated_user]

    live_session :require_authenticated_user,
      on_mount: [{IdentityWeb.Plugs.UserAuth, :require_authenticated}] do
      live "/users/settings", SettingsLive, :edit
      live "/users/settings/confirm-email/:token", SettingsLive, :confirm_email
      live "/users/settings/api-keys", ApiKeysLive, :index
    end

    post "/users/update-password", SessionController, :update_password
  end
end
```

**In `apps/jarga_web/lib/router.ex`:**

```elixir
# Remove all /users/* routes - they are now served by IdentityWeb.Endpoint
# Import auth plugs from identity for use in pipelines

import IdentityWeb.Plugs.UserAuth

pipeline :browser do
  # ...existing plugs...
  plug :fetch_current_scope_for_user  # Now from IdentityWeb.Plugs.UserAuth
end

# Use on_mount hooks from identity
live_session :app,
  on_mount: [
    {IdentityWeb.Plugs.UserAuth, :require_authenticated},
    # ...other hooks
  ] do
  # app routes...
end
```

### Endpoint Configuration

Both endpoints run on different ports (or the same port with different paths via a reverse proxy in production):

**Development:**
- `JargaWeb.Endpoint` - port 4000 (main app)
- `IdentityWeb.Endpoint` - port 4001 (identity/auth)

**Production:**
- Use a reverse proxy (nginx, Caddy) to route `/users/*` to identity endpoint
- Or run both on different subdomains (e.g., `app.example.com`, `auth.example.com`)

---

## Module Renaming Summary

| Old Module | New Module |
|------------|------------|
| `Jarga.Accounts` | `Identity` |
| `Jarga.Accounts.Domain.*` | `Identity.Domain.*` |
| `Jarga.Accounts.Application.*` | `Identity.Application.*` |
| `Jarga.Accounts.Infrastructure.*` | `Identity.Infrastructure.*` |
| `JargaWeb.UserLive.Login` | `IdentityWeb.LoginLive` |
| `JargaWeb.UserLive.Registration` | `IdentityWeb.RegistrationLive` |
| `JargaWeb.UserLive.Settings` | `IdentityWeb.SettingsLive` |
| `JargaWeb.UserLive.Confirmation` | `IdentityWeb.ConfirmationLive` |
| `JargaWeb.ApiKeysLive` | `IdentityWeb.ApiKeysLive` |
| `JargaWeb.UserAuth` | `IdentityWeb.Plugs.UserAuth` |
| `JargaWeb.Plugs.ApiAuthPlug` | `IdentityWeb.Plugs.ApiAuthPlug` |
| `JargaWeb.UserSessionController` | `IdentityWeb.SessionController` |

---

## Cross-Cutting Concerns

### 1. Scope Usage Throughout Codebase

The `Jarga.Accounts.Domain.Scope` module is used extensively across the codebase for authorization. This becomes `Identity.Domain.Scope`.

**Files that import/use Scope (require update):**
- All LiveViews in `jarga_web` that use `@scope`
- All use cases in `jarga` that accept scope parameter
- Authorization policies in documents, projects, workspaces

**Migration Strategy:**
1. Keep `Jarga.Accounts.Domain.Scope` as a thin wrapper that delegates to `Identity.Domain.Scope`
2. Gradually update imports across the codebase
3. Remove wrapper once all references updated

```elixir
# apps/jarga/lib/accounts/domain/scope.ex (deprecated wrapper)
defmodule Jarga.Accounts.Domain.Scope do
  @moduledoc "Deprecated: Use Identity.Domain.Scope instead"
  
  defdelegate struct_fields(), to: Identity.Domain.Scope
  # ... delegate all functions
end
```

### 2. Database Access

The identity app needs database access for user, token, and API key storage.

**Strategy (two-phase):**

**Phase 1-6: Use Jarga.Repo temporarily**
- Identity depends on `:jarga` for Repo access
- Schemas reference `Jarga.Repo`
- Minimizes initial migration complexity

**Phase 7: Create Identity.Repo (long-term solution)**
- Create `Identity.Repo` module
- Move user/token/api_key migrations to `apps/identity/priv/repo/migrations/`
- Configure `Identity.Repo` in umbrella config
- Update all schemas and repositories to use `Identity.Repo`
- Remove dependency on `:jarga` for database access

This provides clean separation where identity owns its own data.

### 3. Email Delivery

The `UserNotifier` uses Swoosh for email delivery. The identity app is generated with mailer support (`mix phx.new identity --no-ecto`), which scaffolds Swoosh configuration. Mailer settings should be consolidated at the umbrella level in `config/config.exs`.

### 4. Session Storage

Sessions are stored in the database via `UserTokenSchema`. The identity app manages this through its own endpoint (`IdentityWeb.Endpoint`).

**Session Sharing Strategy:**

Since identity and jarga_web run as separate endpoints, they need to share session data:

1. **Shared Session Cookie**: Both endpoints use the same session cookie name and signing salt
2. **Shared PubSub**: Both apps use `Jarga.PubSub` for real-time features
3. **Exported Plugs**: `IdentityWeb.Plugs.UserAuth` exports plug functions that `jarga_web` imports for its pipelines

```elixir
# In config/config.exs - shared session configuration
config :jarga_web, :session_options,
  store: :cookie,
  key: "_jarga_key",
  signing_salt: "shared_salt",
  same_site: "Lax"

config :identity, :session_options,
  store: :cookie,
  key: "_jarga_key",  # Same key as jarga_web
  signing_salt: "shared_salt",  # Same salt as jarga_web
  same_site: "Lax"
```

---

## Files to Update in `jarga_web`

After extraction, update these files to use identity:

### Router Updates

```elixir
# apps/jarga_web/lib/router.ex

# 1. Remove the local UserAuth import:
# - import JargaWeb.UserAuth

# 2. Add import from identity:
import IdentityWeb.Plugs.UserAuth

# 3. Remove all /users/* routes (they're now served by IdentityWeb.Endpoint)

# 4. Update pipeline to use imported plugs:
pipeline :browser do
  # ...existing plugs...
  plug :fetch_current_scope_for_user  # Now from IdentityWeb.Plugs.UserAuth
end

# 5. Update live_session on_mount hooks
live_session :app,
  on_mount: [
    {IdentityWeb.Plugs.UserAuth, :require_authenticated},
    # ... other hooks
  ] do
  # app routes...
end
```

### Files to Delete from `jarga_web`

After migration, delete these files (they now live in identity):

```
lib/user_auth.ex
lib/plugs/api_auth_plug.ex
lib/controllers/user_session_controller.ex
lib/live/user_live/login.ex
lib/live/user_live/registration.ex
lib/live/user_live/settings.ex
lib/live/user_live/confirmation.ex
lib/live/api_keys_live.ex
```

### LiveView Hooks

Any LiveView using `on_mount: {JargaWeb.UserAuth, ...}` needs updating:

```elixir
# Before
on_mount: {JargaWeb.UserAuth, :ensure_authenticated}

# After  
on_mount: {IdentityWeb.Plugs.UserAuth, :require_authenticated}
```

### Links to Identity Routes

Update any links pointing to identity routes to use the correct URL:

```elixir
# Before (assuming same endpoint)
~p"/users/settings"

# After (link to identity endpoint)
# Option 1: Use verified routes with endpoint
IdentityWeb.Router.Helpers.settings_path(IdentityWeb.Endpoint, :edit)

# Option 2: Configure identity URL helper in jarga_web
# In jarga_web.ex:
def identity_url(path), do: "#{Application.get_env(:identity, :base_url)}#{path}"
```

---

## Migration Plan

### Phase 1: Create Identity App Structure

1. Generate new Phoenix app: `mix phx.new identity --no-ecto --no-assets`
2. Configure `IdentityWeb.Endpoint` with shared session settings
3. Set up directory structure (domain/application/infrastructure layers)
4. Add umbrella dependencies
5. Configure endpoint in `config/config.exs`, `config/dev.exs`, `config/test.exs`, `config/runtime.exs`
6. Set up `IdentityWeb.Router` with identity routes

### Phase 2: Move Domain Layer

1. Move entities, policies, services from `jarga/accounts/domain/`
2. Update module namespaces
3. Add deprecated wrappers in `jarga` for backward compatibility
4. Run tests to verify

### Phase 3: Move Application Layer

1. Move use cases, behaviours, services
2. Update imports and module references
3. Run tests to verify

### Phase 4: Move Infrastructure Layer

1. Move schemas, repositories, queries, notifiers
2. Update Repo references (point to `Jarga.Repo` initially)
3. Run tests to verify

### Phase 5: Move Web Layer

1. Move LiveViews, plugs, controller
2. Create `IdentityWeb.Router`
3. Update `jarga_web` to forward routes
4. Update all `on_mount` hooks across `jarga_web`
5. Run full test suite including BDD features

### Phase 6: Cleanup

1. Remove deprecated wrappers from `jarga`
2. Delete moved files from original locations
3. Update documentation
4. Final test run

### Phase 7: Create Identity.Repo (Future)

1. Create `Identity.Repo` module
2. Move migrations for `users`, `users_tokens`, `api_keys` tables to `apps/identity/priv/repo/migrations/`
3. Configure `Identity.Repo` in `config/config.exs`
4. Update all identity schemas to use `Identity.Repo`
5. Update repositories to use `Identity.Repo`
6. Remove `:jarga` dependency (identity becomes standalone)
7. Run migrations and verify

---

## Testing Strategy

### Unit Tests
- Move alongside their modules
- Update module references

### Integration Tests
- BDD features move to `apps/identity/test/features/`
- Update step definitions for new module names

### Cross-App Testing
- Ensure `jarga_web` tests still pass with identity as dependency
- Verify authentication flows work end-to-end

---

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| Circular dependencies | Identity depends on jarga (for Repo), jarga_web depends on identity. No circular deps. |
| Breaking existing functionality | Deprecated wrappers provide backward compatibility |
| Complex git history | Use a single feature branch, atomic commits per phase |
| Session/cookie issues | Thorough testing of auth flows in staging |

---

## Success Criteria

1. All existing authentication tests pass
2. All existing BDD features pass
3. No direct references to `Jarga.Accounts.*` in `jarga_web`
4. Clear boundary between identity and other apps
5. `mix boundary` passes with no violations

---

## Decisions

1. **Naming**: `identity` - consolidates users, authentication, sessions, and API keys
2. **Repo ownership**: Yes, `Identity.Repo` will be created as the long-term solution (Phase 7)
3. **API workspace access**: These use cases (`list_accessible_workspaces`, `get_workspace_with_details`, `create_project_via_api`, `get_project_with_documents_via_api`) remain in `jarga` as they cross domain boundaries into workspaces/projects

---

## Appendix: Complete File Inventory

### Files Moving FROM `jarga_web` (8 files)

```
lib/live/user_live/login.ex
lib/live/user_live/registration.ex
lib/live/user_live/settings.ex
lib/live/user_live/confirmation.ex
lib/live/api_keys_live.ex
lib/user_auth.ex
lib/plugs/api_auth_plug.ex
lib/controllers/user_session_controller.ex
```

### Files Moving FROM `jarga` (31 files)

```
lib/accounts.ex
lib/accounts/domain/entities/user.ex
lib/accounts/domain/entities/user_token.ex
lib/accounts/domain/entities/api_key.ex
lib/accounts/domain/policies/authentication_policy.ex
lib/accounts/domain/policies/api_key_policy.ex
lib/accounts/domain/policies/workspace_access_policy.ex
lib/accounts/domain/services/token_builder.ex
lib/accounts/domain/scope.ex
lib/accounts/application/use_cases/register_user.ex
lib/accounts/application/use_cases/login_by_magic_link.ex
lib/accounts/application/use_cases/generate_session_token.ex
lib/accounts/application/use_cases/deliver_login_instructions.ex
lib/accounts/application/use_cases/update_user_password.ex
lib/accounts/application/use_cases/update_user_email.ex
lib/accounts/application/use_cases/deliver_user_update_email_instructions.ex
lib/accounts/application/use_cases/create_api_key.ex
lib/accounts/application/use_cases/list_api_keys.ex
lib/accounts/application/use_cases/update_api_key.ex
lib/accounts/application/use_cases/revoke_api_key.ex
lib/accounts/application/use_cases/verify_api_key.ex
lib/accounts/application/services/password_service.ex
lib/accounts/application/services/api_key_token_service.ex
lib/accounts/application/behaviours/user_repository_behaviour.ex
lib/accounts/application/behaviours/user_token_repository_behaviour.ex
lib/accounts/application/behaviours/user_schema_behaviour.ex
lib/accounts/application/behaviours/user_notifier_behaviour.ex
lib/accounts/application/behaviours/api_key_repository_behaviour.ex
lib/accounts/infrastructure/schemas/user_schema.ex
lib/accounts/infrastructure/schemas/user_token_schema.ex
lib/accounts/infrastructure/schemas/api_key_schema.ex
lib/accounts/infrastructure/repositories/user_repository.ex
lib/accounts/infrastructure/repositories/user_token_repository.ex
lib/accounts/infrastructure/repositories/api_key_repository.ex
lib/accounts/infrastructure/queries/queries.ex
lib/accounts/infrastructure/queries/api_key_queries.ex
lib/accounts/infrastructure/services/token_generator.ex
lib/accounts/infrastructure/notifiers/user_notifier.ex
```

### Test Files to Move (11 files + 5 features)

```
# From jarga_web
test/live/user_live/login_test.exs
test/live/user_live/registration_test.exs
test/live/user_live/settings_test.exs
test/live/user_live/confirmation_test.exs
test/plugs/api_auth_plug_test.exs
test/user_auth_test.exs
test/features/accounts/authentication.feature
test/features/accounts/email.feature
test/features/accounts/password.feature
test/features/accounts/registration.feature
test/features/accounts/sessions.feature

# From jarga (accounts tests - need to identify)
test/accounts/**/*_test.exs
```
