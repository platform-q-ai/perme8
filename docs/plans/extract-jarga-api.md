# Plan: Extract API from `jarga`/`jarga_web` into `jarga_api`

## Context

Currently, API concerns are split across two apps:
- **`jarga`** — holds API-specific business logic in `Jarga.Accounts` (use cases like `CreateProjectViaApi`, `GetWorkspaceWithDetails`, `ListAccessibleWorkspaces`, `GetProjectWithDocumentsViaApi`, and domain module `ApiKeyScope`)
- **`jarga_web`** — holds the API controllers, JSON views, auth plug, routes, and tests alongside the browser/LiveView code

This refactoring creates a new **`jarga_api`** umbrella app that owns the entire API surface: its own Phoenix endpoint, router, controllers, JSON views, auth plug, and the API-specific use cases and domain logic currently in `Jarga.Accounts`.

---

## Phase 1: Scaffold the `jarga_api` app

1. **Generate a new Phoenix API-only app** in the umbrella:
   ```bash
   cd apps && mix phx.new jarga_api --no-ecto --no-html --no-assets
   ```
   This gives us a lean Phoenix app with endpoint, router, telemetry, and JSON error handling — no HTML, no Ecto, no assets.

2. **Configure dependencies** in `apps/jarga_api/mix.exs`:
   - `{:jarga, in_umbrella: true}` — for workspace/project/document contexts
   - `{:identity, in_umbrella: true}` — for API key verification and user lookup
   - `{:boundary, "~> 0.10", runtime: false}`
   - `{:jason, "~> 1.2"}`
   - Remove any unnecessary generated deps

3. **Configure the endpoint** in root `config/`:
   - `JargaApi.Endpoint` — JSON-only, separate port (e.g., 4001 dev, 4003 test)
   - Add `render_errors: [formats: [json: JargaApi.ErrorJSON]]`
   - No session, no CSRF, no browser pipeline

4. **Set up boundary declarations** in `apps/jarga_api/lib/jarga_api.ex`:
   ```elixir
   use Boundary,
     deps: [Jarga.Workspaces, Jarga.Projects, Jarga.Documents, Identity, JargaApi.Accounts],
     exports: [Endpoint]
   ```

---

## Phase 2: Move API web layer from `jarga_web` to `jarga_api`

Files to **move** (with module renaming `JargaWeb.*` → `JargaApi.*`):

| Source (jarga_web) | Destination (jarga_api) | New Module Name |
|---|---|---|
| `lib/plugs/api_auth_plug.ex` | `lib/jarga_api/plugs/api_auth_plug.ex` | `JargaApi.Plugs.ApiAuthPlug` |
| `lib/controllers/workspace_api_controller.ex` | `lib/jarga_api/controllers/workspace_api_controller.ex` | `JargaApi.WorkspaceApiController` |
| `lib/controllers/workspace_api_json.ex` | `lib/jarga_api/controllers/workspace_api_json.ex` | `JargaApi.WorkspaceApiJSON` |
| `lib/controllers/project_api_controller.ex` | `lib/jarga_api/controllers/project_api_controller.ex` | `JargaApi.ProjectApiController` |
| `lib/controllers/project_api_json.ex` | `lib/jarga_api/controllers/project_api_json.ex` | `JargaApi.ProjectApiJSON` |

5. **Create `JargaApi.Router`** with the API pipelines and routes:
   ```elixir
   pipeline :api do
     plug :accepts, ["json"]
   end

   pipeline :api_authenticated do
     plug :accepts, ["json"]
     plug JargaApi.Plugs.ApiAuthPlug
   end

   scope "/api", JargaApi do
     pipe_through :api_authenticated

     get "/workspaces", WorkspaceApiController, :index
     get "/workspaces/:slug", WorkspaceApiController, :show
     post "/workspaces/:workspace_slug/projects", ProjectApiController, :create
     get "/workspaces/:workspace_slug/projects/:slug", ProjectApiController, :show
   end
   ```

6. **Create `JargaApi.ErrorJSON`** (copy/adapt from `JargaWeb.ErrorJSON`).

7. **Update controllers** to `use JargaApi, :controller` instead of `use JargaWeb, :controller`. Create the `JargaApi` module with a `controller/0` macro similar to `JargaWeb` but JSON-only (no HTML, no verified routes with browser statics).

8. **Update `ApiAuthPlug`** to alias `JargaApi.Accounts` (or reference `Identity` directly — see Phase 3).

---

## Phase 3: Move API business logic from `jarga` to `jarga_api`

The API-specific use cases and domain logic currently in `Jarga.Accounts` should move to a new `JargaApi.Accounts` context within the `jarga_api` app:

| Source (jarga) | Destination (jarga_api) | New Module |
|---|---|---|
| `lib/accounts/domain/api_key_scope.ex` | `lib/jarga_api/accounts/domain/api_key_scope.ex` | `JargaApi.Accounts.Domain.ApiKeyScope` |
| `lib/accounts/application/use_cases/list_accessible_workspaces.ex` | `lib/jarga_api/accounts/application/use_cases/list_accessible_workspaces.ex` | `JargaApi.Accounts.Application.UseCases.ListAccessibleWorkspaces` |
| `lib/accounts/application/use_cases/get_workspace_with_details.ex` | `lib/jarga_api/accounts/application/use_cases/get_workspace_with_details.ex` | `JargaApi.Accounts.Application.UseCases.GetWorkspaceWithDetails` |
| `lib/accounts/application/use_cases/create_project_via_api.ex` | `lib/jarga_api/accounts/application/use_cases/create_project_via_api.ex` | `JargaApi.Accounts.Application.UseCases.CreateProjectViaApi` |
| `lib/accounts/application/use_cases/get_project_with_documents_via_api.ex` | `lib/jarga_api/accounts/application/use_cases/get_project_with_documents_via_api.ex` | `JargaApi.Accounts.Application.UseCases.GetProjectWithDocumentsViaApi` |

9. **Create `JargaApi.Accounts` facade** — a slimmed-down version of `Jarga.Accounts` that only exposes the 4 API operations plus delegates `verify_api_key/1` and `get_user/1` to `Identity`.

10. **Clean up `Jarga.Accounts`** — remove the 4 API-specific use case delegations and the `@moduledoc` references to them. Remove the `Jarga.Accounts.Application` and `Jarga.Accounts.Domain` boundary modules if they become empty. The remaining delegations to `Identity` stay in `Jarga.Accounts` (they serve the browser/LiveView side).

---

## Phase 4: Move tests

| Source | Destination |
|---|---|
| `apps/jarga_web/test/controllers/workspace_api_controller_test.exs` | `apps/jarga_api/test/controllers/workspace_api_controller_test.exs` |
| `apps/jarga_web/test/features/workspaces/api_access.feature` | `apps/jarga_api/test/features/workspaces/api_access.feature` |
| `apps/jarga_web/test/features/projects/api_access.feature` | `apps/jarga_api/test/features/projects/api_access.feature` |
| `apps/jarga_web/test/features/wip/document_api_access.feature` | `apps/jarga_api/test/features/wip/document_api_access.feature` |
| All `apps/jarga_web/test/features/step_definitions/workspaces/api/` | `apps/jarga_api/test/features/step_definitions/workspaces/api/` |
| All `apps/jarga_web/test/features/step_definitions/projects/api/` | `apps/jarga_api/test/features/step_definitions/projects/api/` |
| `apps/jarga/test/accounts/domain/api_key_scope_test.exs` | `apps/jarga_api/test/accounts/domain/api_key_scope_test.exs` |
| `apps/jarga/test/accounts/application/use_cases/list_accessible_workspaces_test.exs` | `apps/jarga_api/test/accounts/application/use_cases/list_accessible_workspaces_test.exs` |
| `apps/jarga/test/accounts/application/use_cases/get_workspace_with_details_test.exs` | `apps/jarga_api/test/accounts/application/use_cases/get_workspace_with_details_test.exs` |

11. **Update test helpers and ConnCase** — `JargaApi.ConnCase` should use `JargaApi.Endpoint` and `JargaApi.Router`.

12. **Update step definitions** — replace `JargaWeb.Endpoint` references with `JargaApi.Endpoint`, update module aliases.

13. **Add test dependencies** to `jarga_api/mix.exs`: `{:cucumber, ...}`, `{:wallaby, ...}` (if needed for BDD steps).

---

## Phase 5: Clean up `jarga_web`

14. **Remove API routes** from `JargaWeb.Router` — delete the `/api` scope and the `:api`/`:api_authenticated` pipelines.

15. **Delete moved files** from `jarga_web`:
    - `lib/plugs/api_auth_plug.ex`
    - `lib/controllers/workspace_api_controller.ex`
    - `lib/controllers/workspace_api_json.ex`
    - `lib/controllers/project_api_controller.ex`
    - `lib/controllers/project_api_json.ex`

16. **Update `JargaWeb` boundary** — remove `Jarga.Accounts` from deps if no longer needed (check if `ApiKeysLive` still uses it — it does for managing API keys in the browser UI, so it likely stays).

17. **Remove API test files** from `jarga_web/test/` (already moved in Phase 4).

---

## Phase 6: Clean up `jarga`

18. **Remove API use cases and domain modules** from `jarga`:
    - Delete `lib/accounts/domain/api_key_scope.ex`
    - Delete `lib/accounts/application/use_cases/create_project_via_api.ex`
    - Delete `lib/accounts/application/use_cases/get_project_with_documents_via_api.ex`
    - Delete `lib/accounts/application/use_cases/get_workspace_with_details.ex`
    - Delete `lib/accounts/application/use_cases/list_accessible_workspaces.ex`

19. **Simplify `Jarga.Accounts`** — remove the 4 API function definitions, update `@moduledoc`, clean up the boundary deps (remove `Jarga.Accounts.Application` if empty).

20. **Remove empty boundary modules** — if `Jarga.Accounts.Application` and `Jarga.Accounts.Domain` are empty after removing API code, delete them.

---

## Phase 7: Integration & verification

21. **Update root config files** (`config.exs`, `dev.exs`, `test.exs`, `prod.exs`, `runtime.exs`):
    - Add `JargaApi.Endpoint` config (port, host, secret_key_base)
    - Add `config :jarga_api, ...` entries

22. **Update deployment** — ensure `JargaApi.Endpoint` starts in `JargaApi.Application` supervisor and is included in releases.

23. **Run `mix boundary.visualize`** (if available) or `mix compile --warnings-as-errors` to verify no boundary violations.

24. **Run the full test suite**:
    ```bash
    mix test                                    # all umbrella tests
    mix test --only jarga_api                   # new API tests
    mix cucumber                                # BDD features
    mix boundary                                # boundary checks
    mix credo                                   # code quality
    ```

25. **Verify API endpoints work** with manual curl/httpie test against the new port.

---

## Dependency Graph (After Refactoring)

```
identity (standalone)
    ↑
  jarga (domain logic, depends on identity)
    ↑              ↑
jarga_web      jarga_api
(browser UI)   (JSON API)
```

Both `jarga_web` and `jarga_api` depend on `jarga` for domain contexts (workspaces, projects, documents) and on `identity` for auth. They are siblings — neither depends on the other.

---

## Key Decisions / Considerations

- **Separate endpoint & port**: `jarga_api` gets its own `JargaApi.Endpoint` on a different port. This allows independent scaling, monitoring, and rate-limiting in production. Alternatively, you could use a reverse proxy to route `/api` to the same port — but a separate endpoint is cleaner.
- **`ApiKeysLive` stays in `jarga_web`**: The browser UI for managing API keys is a browser concern, not an API concern. It continues to delegate to `Jarga.Accounts` → `Identity` for CRUD operations.
- **No shared controllers**: The `use JargaApi, :controller` macro will be JSON-only. No HTML rendering, no verified routes with browser statics.
- **The `Jarga.Accounts` facade thins out significantly**: After the refactoring, it only contains Identity delegations (user auth, session, API key CRUD). The cross-domain API orchestration lives in `JargaApi.Accounts`.
