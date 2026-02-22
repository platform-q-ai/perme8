# AgentsWeb

Phoenix LiveView browser interface for agent sessions. Standalone umbrella app that delegates authentication to Identity via a shared session cookie.

## Architecture

AgentsWeb is a thin interface layer -- it owns routes, LiveViews, JS hooks, and templates. All domain logic lives in the `agents` app (Sessions bounded context).

```
AgentsWeb (this app)        -- LiveViews, JS hooks, router, auth plugs
  -> Agents.Sessions        -- facade for session operations (domain + infra)
  -> Identity               -- user lookup from session token
```

## Authentication

AgentsWeb shares Identity's `_identity_key` session cookie so users authenticated at Identity are automatically authenticated here. No separate login flow exists in this app.

**How it works:**

1. `AgentsWeb.Endpoint` reads `compile_env!(:identity, :session_options)` to share the exact same cookie key, signing salt, and session config as Identity
2. All apps sharing the cookie must use the same `secret_key_base` (aligned in dev.exs, test.exs, and runtime.exs via `SECRET_KEY_BASE` env var)
3. `fetch_current_scope_for_user` plug reads the session token and calls `Identity.get_user_by_session_token/1`
4. `require_authenticated_user` plug redirects unauthenticated users to Identity's login page with a `?return_to=` URL pointing back to AgentsWeb
5. After login, Identity validates the `return_to` URL (localhost-only to prevent open redirects) and redirects back

**Key module:** `AgentsWeb.UserAuth` (`lib/user_auth.ex`)

## Routes

All routes require authentication.

| Method | Path | Handler | Description |
|--------|------|---------|-------------|
| GET | `/sessions` | `SessionsLive.Index` | Sessions LiveView -- instruction form, event log, task history |

## LiveViews

### `AgentsWeb.SessionsLive.Index`

Main sessions interface for running coding tasks in ephemeral opencode containers.

- Instruction form (Enter to submit, Shift+Enter for newline)
- Real-time event log streamed via PubSub from TaskRunner
- Markdown rendering of agent output
- Task history with colour-coded status badges
- Cancel / delete / resume actions

## JS Hooks

| Hook | File | Purpose |
|------|------|---------|
| `SessionLog` | `assets/js/presentation/hooks/session-log-hook.ts` | Auto-scrolls event log using MutationObserver |
| `SubmitForm` | `assets/js/presentation/hooks/session-form-hook.ts` | Enter-to-submit, Shift+Enter-for-newline |

## Dependencies

- **`agents`** (in_umbrella) -- `Agents.Sessions` facade for all session operations
- **`identity`** (in_umbrella) -- session token validation, session cookie config
- **`jarga`** (in_umbrella) -- Ecto repo (sessions_tasks table)
- Phoenix LiveView, Tailwind CSS, daisyUI, esbuild

## Configuration

| Config key | Purpose |
|------------|---------|
| `:agents_web, :identity_url` | Identity app URL for login redirects (defaults to `IdentityWeb.Endpoint.url()`) |
| `:agents_web, AgentsWeb.Endpoint` | Standard Phoenix endpoint config (host, port, secret_key_base) |

**Port assignments:**

| Environment | Port |
|-------------|------|
| dev | 4010 |
| test | 4012 |

**Production env vars** (in `config/runtime.exs`):
- `AGENTS_WEB_HOST` -- hostname (default: `localhost`)
- `AGENTS_WEB_PORT` -- port (default: `4010`)
- `IDENTITY_URL` -- Identity app URL for login redirects
- `SECRET_KEY_BASE` -- must match Identity and all other apps sharing the session cookie

## Testing

### Unit Tests (ExUnit)

```sh
mix test apps/agents_web/test/
```

Covers LiveView mounting, form events, PubSub event handling, and status badges.

### JS Hook Tests (Vitest)

```sh
cd apps/agents_web/assets && npx vitest run
```

### Browser Tests (exo-bdd)

```sh
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents_web/test/exo-bdd-agents-web.config.ts --adapter browser
```

**Feature files:**
- `test/features/sessions/sessions.browser.feature` -- authenticated session scenarios (Background logs in via Identity)
- `test/features/sessions/sessions-auth.browser.feature` -- cross-app auth redirect, login return flow, failed login flash
