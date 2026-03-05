# Feature: Extract Shared SecurityHeaders Plug with :liveview / :api Profiles

**Ticket**: #118
**Type**: Refactor — extract shared infrastructure

## Overview

Seven independent copies of `SecurityHeadersPlug` exist across the umbrella, implementing two functional variants (browser/LiveView CSP vs API CSP) with identical non-CSP headers. This plan extracts them into a single shared module in a new `perme8_plugs` infrastructure app, following the `perme8_events` precedent for shared leaf-node infrastructure.

## Design Decisions

### 1. New umbrella app: `perme8_plugs`

**Decision**: Create a new `perme8_plugs` app under `apps/`.

**Rationale**:
- No existing shared web/plug infrastructure app exists.
- `perme8_events` sets the precedent: leaf-node shared infrastructure with no domain dependencies.
- Naming follows the `perme8_` prefix convention for shared infrastructure (`perme8_events`, `perme8_tools`).
- Keeps plug infrastructure decoupled from any domain app.
- All 7 consumer apps can add `{:perme8_plugs, in_umbrella: true}` as a dependency.

**App structure**:
```
apps/perme8_plugs/
├── lib/
│   ├── perme8_plugs.ex               # OTP app container boundary
│   └── perme8/
│       └── plugs/
│           └── security_headers.ex    # The shared plug
├── test/
│   └── perme8/
│       └── plugs/
│           └── security_headers_test.exs
├── mix.exs
└── .formatter.exs
```

### 2. Module name: `Perme8.Plugs.SecurityHeaders`

**Decision**: `Perme8.Plugs.SecurityHeaders` (no `Plug` suffix).

**Rationale**:
- Follows Phoenix convention where plugs are named after what they do (e.g., `Plug.Session`, `Plug.Head`), not suffixed with `Plug`.
- The `Perme8.Plugs` namespace leaves room for future shared plugs (e.g., `Perme8.Plugs.RequestId`, `Perme8.Plugs.RateLimiter`).
- The boundary `Perme8.Plugs` mirrors `Perme8.Events` from `perme8_events`.

### 3. Profile option: compile-time via `init/1`

**Decision**: The `:profile` option is resolved at compile-time in `init/1`, which is called once when the plug is compiled into the endpoint/router pipeline.

**Rationale**:
- Plug's `init/1` is called at compile-time for module plugs in endpoints/routers. The profile never changes at runtime.
- Pre-computing the CSP string in `init/1` avoids any runtime overhead.
- `call/2` receives the pre-computed config and just sets headers — maximum performance.

**API**:
```elixir
# In endpoint (browser/LiveView app):
plug Perme8.Plugs.SecurityHeaders, profile: :liveview

# In router pipeline (API app):
plug Perme8.Plugs.SecurityHeaders, profile: :api
```

**Error handling**: `init/1` raises `ArgumentError` if `:profile` is missing or not `:liveview` / `:api`.

### 4. Old modules: completely removed

**Decision**: Delete all 7 original `SecurityHeadersPlug` modules entirely. Do not leave thin wrappers.

**Rationale**:
- Thin delegating wrappers add indirection for zero benefit — all consumer sites are simple `plug` calls that are trivially updated.
- Only 7 files to update (2 endpoints + 5 routers) — low migration effort.
- Clean removal avoids confusion about which module to use.
- All 7 test files are also removed (their coverage moves to the shared test).

## UI Strategy

- **LiveView coverage**: N/A (infrastructure-only change)
- **TypeScript needed**: None

## Affected Boundaries

- **New app**: `perme8_plugs` (shared infrastructure, leaf-node)
- **Repo**: None (no database)
- **Migrations**: None
- **Primary context**: `Perme8.Plugs` (boundary)
- **Dependencies**: None (depends only on `plug` library)
- **Exported modules**: `Perme8.Plugs.SecurityHeaders`
- **Consumer apps**: `jarga_web`, `identity`, `jarga_api`, `agents_api`, `webhooks_api`, `entity_relationship_manager`, `agents`

## Phase 1: Domain — Shared Plug Module (phoenix-tdd)

This phase creates the new `perme8_plugs` app and implements the shared plug with full test coverage.

### Step 1.1: Scaffold `perme8_plugs` Umbrella App

- [ ] ⏸ Create `apps/perme8_plugs/mix.exs` (modeled on `perme8_events/mix.exs`)
  - OTP app: `:perme8_plugs`
  - Dependencies: `{:plug, "~> 1.16"}`, `{:boundary, "~> 0.10", runtime: false}`
  - Compilers: `[:boundary] ++ Mix.compilers()`
  - No Application module needed (no supervised processes)
- [ ] ⏸ Create `apps/perme8_plugs/.formatter.exs`
- [ ] ⏸ Create `apps/perme8_plugs/lib/perme8_plugs.ex` — boundary container:
  ```elixir
  defmodule Perme8Plugs do
    @moduledoc false
    use Boundary, top_level?: true, deps: [], exports: []
  end
  ```
- [ ] ⏸ Create `apps/perme8_plugs/test/test_helper.exs`

### Step 1.2: `Perme8.Plugs.SecurityHeaders` — Shared Plug

- [ ] ⏸ **RED**: Write test `apps/perme8_plugs/test/perme8/plugs/security_headers_test.exs`
  - Tests for `:liveview` profile:
    - Sets all 5 non-CSP headers (x-content-type-options, x-frame-options, referrer-policy, strict-transport-security, permissions-policy)
    - CSP includes `default-src 'self'`, `script-src 'self' 'unsafe-inline'`, `style-src 'self' 'unsafe-inline'`, `img-src 'self' data:`, `font-src 'self'`, `connect-src 'self'`, `frame-ancestors 'none'`, `form-action 'self'`, `base-uri 'self'`, `object-src 'none'`, `media-src 'none'`
  - Tests for `:api` profile:
    - Sets all 5 non-CSP headers (identical values)
    - CSP is `default-src 'none'`
  - Tests for `init/1`:
    - `init(profile: :liveview)` returns a map/keyword with pre-computed CSP string
    - `init(profile: :api)` returns a map/keyword with pre-computed CSP string
    - `init([])` raises `ArgumentError` (missing profile)
    - `init(profile: :unknown)` raises `ArgumentError` (invalid profile)
  - Test that `call/2` uses pre-computed config (does not re-compute)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_plugs/lib/perme8/plugs/security_headers.ex`
  - `@behaviour Plug`
  - `init/1`: validates `:profile` option, pre-computes CSP string, returns `%{csp: csp_string}`
  - `call/2`: sets all 6 headers using the pre-computed config
  - Module attribute constants for shared headers
  - LiveView CSP as module attribute (same as existing JargaWeb/IdentityWeb)
  - API CSP as module attribute (`"default-src 'none'"`)
- [ ] ⏸ **REFACTOR**: Extract shared header constants, ensure clean docs

### Step 1.3: Boundary Configuration

- [ ] ⏸ Create/update `apps/perme8_plugs/lib/perme8/plugs.ex` — public API boundary:
  ```elixir
  defmodule Perme8.Plugs do
    @moduledoc "Shared Plug infrastructure for the Perme8 umbrella."
    use Boundary, top_level?: true, deps: [], exports: [SecurityHeaders]
  end
  ```

### Phase 1 Validation

- [ ] ⏸ All shared plug tests pass: `mix test` in `apps/perme8_plugs/`
- [ ] ⏸ No boundary violations: `mix boundary` (from umbrella root)
- [ ] ⏸ App compiles standalone: `mix compile` in `apps/perme8_plugs/`

---

## Phase 2: Infrastructure — Migrate All Consumers (phoenix-tdd)

This phase updates all 7 consumer apps to use the shared plug, removes old implementations, and updates tests.

### Step 2.1: Add Dependency to All Consumer Apps

Update `mix.exs` in each consumer app to add `{:perme8_plugs, in_umbrella: true}`:

- [ ] ⏸ `apps/jarga_web/mix.exs`
- [ ] ⏸ `apps/identity/mix.exs`
- [ ] ⏸ `apps/jarga_api/mix.exs`
- [ ] ⏸ `apps/agents_api/mix.exs`
- [ ] ⏸ `apps/webhooks_api/mix.exs`
- [ ] ⏸ `apps/entity_relationship_manager/mix.exs`
- [ ] ⏸ `apps/agents/mix.exs`

### Step 2.2: Update Endpoints/Routers to Use Shared Plug

Each consumer replaces its local plug reference with the shared module.

#### 2.2.1: JargaWeb (LiveView — endpoint)

- [ ] ⏸ **RED**: Update test expectations (verify the test file to be deleted still passes with old plug before switchover)
- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/endpoint.ex` line 56:
  ```diff
  - plug(JargaWeb.Plugs.SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :liveview)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/jarga_web/lib/plugs/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/jarga_web/test/plugs/security_headers_plug_test.exs`

#### 2.2.2: Identity (LiveView — endpoint)

- [ ] ⏸ **RED**: Verify existing test still passes before switchover
- [ ] ⏸ **GREEN**: Update `apps/identity/lib/identity_web/endpoint.ex` line 49:
  ```diff
  - plug IdentityWeb.Plugs.SecurityHeadersPlug
  + plug Perme8.Plugs.SecurityHeaders, profile: :liveview
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/identity/lib/identity_web/plugs/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/identity/test/identity_web/plugs/security_headers_plug_test.exs`

#### 2.2.3: JargaApi (API — router)

- [ ] ⏸ **RED**: Verify existing test still passes before switchover
- [ ] ⏸ **GREEN**: Update `apps/jarga_api/lib/jarga_api/router.ex` line 8:
  ```diff
  - plug(JargaApi.Plugs.SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :api)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/jarga_api/lib/jarga_api/plugs/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/jarga_api/test/jarga_api/plugs/security_headers_plug_test.exs`

#### 2.2.4: AgentsApi (API — router)

- [ ] ⏸ **RED**: Verify existing test still passes before switchover
- [ ] ⏸ **GREEN**: Update `apps/agents_api/lib/agents_api/router.ex` line 7:
  ```diff
  - plug(AgentsApi.Plugs.SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :api)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/agents_api/lib/agents_api/plugs/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/agents_api/test/agents_api/plugs/security_headers_plug_test.exs`

#### 2.2.5: WebhooksApi (API — router)

- [ ] ⏸ **GREEN**: Update `apps/webhooks_api/lib/webhooks_api/router.ex` line 6:
  ```diff
  - plug(WebhooksApi.Plugs.SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :api)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/webhooks_api/lib/webhooks_api/plugs/security_headers_plug.ex`
  - Note: No unit test exists for this plug (BDD coverage only)

#### 2.2.6: EntityRelationshipManager (API — router)

- [ ] ⏸ **RED**: Verify existing test still passes before switchover
- [ ] ⏸ **GREEN**: Update `apps/entity_relationship_manager/lib/entity_relationship_manager/router.ex` line 6:
  ```diff
  - plug(EntityRelationshipManager.Plugs.SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :api)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/entity_relationship_manager/test/entity_relationship_manager/plugs/security_headers_plug_test.exs`

#### 2.2.7: Agents MCP (API — Plug.Router)

- [ ] ⏸ **RED**: Verify existing test still passes before switchover
- [ ] ⏸ **GREEN**: Update `apps/agents/lib/agents/infrastructure/mcp/router.ex` lines 23-25:
  ```diff
  - alias Agents.Infrastructure.Mcp.SecurityHeadersPlug
  -
  - plug(SecurityHeadersPlug)
  + plug(Perme8.Plugs.SecurityHeaders, profile: :api)
  ```
- [ ] ⏸ **REFACTOR**: Delete `apps/agents/lib/agents/infrastructure/mcp/security_headers_plug.ex`
- [ ] ⏸ **REFACTOR**: Delete `apps/agents/test/agents/infrastructure/mcp/security_headers_plug_test.exs`

### Step 2.3: Clean Up Empty Directories

After deleting plug files, check for and remove empty `plugs/` directories:

- [ ] ⏸ Check if `apps/jarga_web/lib/plugs/` is empty after removal → delete if so
- [ ] ⏸ Check if `apps/jarga_api/lib/jarga_api/plugs/` has other files → only delete if empty
- [ ] ⏸ Check if `apps/webhooks_api/lib/webhooks_api/plugs/` has other files → only delete if empty
- [ ] ⏸ Check if `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/` has other files → only delete if empty
- [ ] ⏸ Check if `apps/agents_api/lib/agents_api/plugs/` has other files → only delete if empty
- [ ] ⏸ Check if `apps/identity/lib/identity_web/plugs/` has other files → only delete if empty

### Step 2.4: Update BDD Feature File Comments

The ERM security headers BDD feature file and several other `.security.feature` files reference `SecurityHeadersPlug` in comments. Update these references:

- [ ] ⏸ Update `apps/entity_relationship_manager/test/features/security_headers.security.feature` line 34 comment
- [ ] ⏸ Update `apps/webhooks_api/test/features/webhooks/webhooks.security.feature` line 350 comment
- [ ] ⏸ Update `apps/jarga_api/test/features/workspaces.security.feature` line 188 comment
- [ ] ⏸ Update `apps/jarga_api/test/features/projects.security.feature` lines 171, 186 comments
- [ ] ⏸ Update `apps/jarga_api/test/features/documents.security.feature` line 189 comment

### Phase 2 Validation

- [ ] ⏸ All shared plug tests pass: `mix test apps/perme8_plugs/`
- [ ] ⏸ All consumer app tests pass: `mix test` (umbrella-wide)
- [ ] ⏸ No boundary violations: `mix boundary`
- [ ] ⏸ No compilation warnings: `mix compile --warnings-as-errors`
- [ ] ⏸ Full pre-commit check: `mix precommit`

---

## Phase 3: Documentation & Ownership Updates

### Step 3.1: Update `docs/app_ownership.md`

- [ ] ⏸ Add `perme8_plugs` to the Ownership Registry table:
  ```
  | **perme8_plugs** | Shared infrastructure | Shared Plug modules (SecurityHeaders) | None | Nothing (foundational) |
  ```
- [ ] ⏸ Add to the dependency graph in `docs/umbrella_apps.md`:
  - `perme8_plugs` depends on nothing in the umbrella (leaf-node, same as `perme8_events`)
  - All 7 consumer apps depend on `perme8_plugs`

### Step 3.2: Update `docs/umbrella_apps.md`

- [ ] ⏸ Add `perme8_plugs` to the umbrella apps table:
  ```
  | `perme8_plugs` | Elixir (shared infra) | -- | Shared Plug modules (SecurityHeaders, future shared plugs) |
  ```
- [ ] ⏸ Update the dependency graph section

### Phase 3 Validation

- [ ] ⏸ Documentation is consistent with code changes
- [ ] ⏸ `docs/app_ownership.md` has been updated

---

## Summary: Files Created / Modified / Deleted

### Created (4 files)

| File | Purpose |
|------|---------|
| `apps/perme8_plugs/mix.exs` | New umbrella app definition |
| `apps/perme8_plugs/.formatter.exs` | Code formatter config |
| `apps/perme8_plugs/lib/perme8_plugs.ex` | OTP app boundary container |
| `apps/perme8_plugs/lib/perme8/plugs.ex` | Public API boundary (`Perme8.Plugs`) |
| `apps/perme8_plugs/lib/perme8/plugs/security_headers.ex` | **The shared plug** |
| `apps/perme8_plugs/test/test_helper.exs` | Test helper |
| `apps/perme8_plugs/test/perme8/plugs/security_headers_test.exs` | **Comprehensive test** |

### Modified (19 files)

| File | Change |
|------|--------|
| `apps/jarga_web/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/identity/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/jarga_api/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/agents_api/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/webhooks_api/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/entity_relationship_manager/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/agents/mix.exs` | Add `{:perme8_plugs, in_umbrella: true}` dep |
| `apps/jarga_web/lib/endpoint.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :liveview` |
| `apps/identity/lib/identity_web/endpoint.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :liveview` |
| `apps/jarga_api/lib/jarga_api/router.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :api` |
| `apps/agents_api/lib/agents_api/router.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :api` |
| `apps/webhooks_api/lib/webhooks_api/router.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :api` |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/router.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :api` |
| `apps/agents/lib/agents/infrastructure/mcp/router.ex` | `plug Perme8.Plugs.SecurityHeaders, profile: :api` |
| `docs/app_ownership.md` | Add `perme8_plugs` entry |
| `docs/umbrella_apps.md` | Add `perme8_plugs` entry and update dep graph |
| 5 × `.security.feature` files | Update `SecurityHeadersPlug` comment references |

### Deleted (13 files)

| File | Reason |
|------|--------|
| `apps/jarga_web/lib/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/jarga_web/test/plugs/security_headers_plug_test.exs` | Coverage moved to shared test |
| `apps/identity/lib/identity_web/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/identity/test/identity_web/plugs/security_headers_plug_test.exs` | Coverage moved to shared test |
| `apps/jarga_api/lib/jarga_api/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/jarga_api/test/jarga_api/plugs/security_headers_plug_test.exs` | Coverage moved to shared test |
| `apps/agents_api/lib/agents_api/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/agents_api/test/agents_api/plugs/security_headers_plug_test.exs` | Coverage moved to shared test |
| `apps/webhooks_api/lib/webhooks_api/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/entity_relationship_manager/lib/entity_relationship_manager/plugs/security_headers_plug.ex` | Replaced by shared plug |
| `apps/entity_relationship_manager/test/entity_relationship_manager/plugs/security_headers_plug_test.exs` | Coverage moved to shared test |
| `apps/agents/lib/agents/infrastructure/mcp/security_headers_plug.ex` | Replaced by shared plug |
| `apps/agents/test/agents/infrastructure/mcp/security_headers_plug_test.exs` | Coverage moved to shared test |

## Testing Strategy

- **Total estimated tests**: ~15 (in single shared test file)
- **Distribution**:
  - Shared plug (Phase 1): ~15 tests
    - `init/1` validation: 4 tests (valid :liveview, valid :api, missing profile, invalid profile)
    - `:liveview` profile headers: 6 tests (5 non-CSP + 1 comprehensive CSP)
    - `:api` profile headers: 2 tests (CSP value + all-headers-present)
    - Cross-profile shared headers: 2 tests (verify non-CSP headers are identical for both profiles)
    - `@behaviour Plug` compliance: 1 test
  - Consumer app tests (Phase 2): 0 new tests (existing integration/BDD tests provide coverage)

**Net test change**: +15 new tests, -~45 deleted tests across 6 files = net -30 tests.
This is correct because the 6 old test files were redundant copies testing identical logic. The shared test covers both profiles comprehensively. Integration-level coverage is provided by existing BDD `.security.feature` files and endpoint/router integration tests.

## Pre-Commit Checkpoint

After Phase 2 completion:

```bash
mix compile --warnings-as-errors  # No warnings
mix boundary                       # No boundary violations
mix format --check-formatted       # Code formatted
mix credo                          # Style compliance
mix test                           # All tests pass
mix precommit                      # Full pre-commit suite
```

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Boundary violations from new dependency | Low | `perme8_plugs` is a leaf-node with no deps; consumers only add it as a dep |
| CSP mismatch between old and new | Low | Tests verify exact same header values; profiles map 1:1 to existing variants |
| Missing `profile:` option in consumer | Low | `init/1` raises `ArgumentError` at compile time — caught immediately |
| Empty `plugs/` dirs left behind | Low | Explicit cleanup step in Phase 2.3 |
| BDD security feature tests break | Very Low | Feature tests check header presence/values, not module names; headers unchanged |
