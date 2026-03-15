# Feature: Migrate Jarga from Identity.Repo to Jarga.Repo

**Ticket:** [#449](https://github.com/platform-q-ai/perme8/issues/449)
**Status:** ⏸ Not Started

## Overview

Jarga currently violates the Standalone App Principle by aliasing `Identity.Repo` throughout its production code, using `belongs_to` associations to Identity schemas, and performing cross-schema joins against Identity tables. This refactoring:

1. **Switches all production `Identity.Repo` references to `Jarga.Repo`** (drop-in replacement — both repos point to the same database)
2. **Replaces `belongs_to` associations to Identity schemas with plain `field(:x, :binary_id)` declarations** (following Chat's precedent)
3. **Replaces cross-schema joins against Identity tables with Identity facade API calls** (clean boundary separation)

**Zero runtime behavior change.** No migrations needed. All 604 tests must continue passing.

## UI Strategy

- **LiveView coverage**: N/A (no UI changes)
- **TypeScript needed**: None

## Affected Boundaries

- **Owning app**: `jarga`
- **Repo**: `Jarga.Repo` (target state)
- **Migrations**: None required
- **Primary contexts**: `Jarga.Projects`, `Jarga.Documents`, `Jarga.Notes`
- **Dependencies**: `Identity` (public facade API — `Identity.member?/2`, `Identity.verify_membership/2`, `Identity.get_workspace/2`)
- **New context needed?**: No

## Key Constraints

1. Zero runtime behavior change
2. No migrations needed (both repos share the same PostgreSQL database)
3. All 604 tests must continue passing
4. Follow Chat's precedent for plain field declarations (see `apps/chat/lib/chat/infrastructure/schemas/session_schema.ex`)
5. Test sandbox setup MUST still check out BOTH `Identity.Repo` and `Jarga.Repo` (shared database, Identity-owned entities in fixtures)
6. Jarga legitimately depends on Identity's public facade API — don't remove `Identity` from Boundary deps entirely
7. DO remove `Identity.Repo` from Boundary deps in all production modules

## Important Sandbox Notes

Test fixtures create Identity-owned entities (users, workspaces, workspace_members) via `Identity.Repo`. Those `Identity.Repo` references in test fixtures **MUST STAY** because they are operating on Identity-owned data. Only Jarga-owned operations should switch to `Jarga.Repo`.

The `data_case.ex` and `sandbox_helper.ex` check out both `Identity.Repo` and `Jarga.Repo` for the shared database sandbox — this MUST remain unchanged.

---

## Phase 1: Switch Identity.Repo → Jarga.Repo in Production Code

**Goal:** Replace all `Identity.Repo` aliases/references in Jarga production code with `Jarga.Repo`. Remove `Identity.Repo` from Boundary deps in production modules. This is a drop-in replacement with zero runtime change.

### Step 1.1: Update Boundary Declarations (5 production files)

Remove `Identity.Repo` from `deps` list in all production Boundary declarations. `Identity` stays (for facade API).

- [ ] **RED**: Run `mix boundary` — confirm current state compiles cleanly with existing deps
- [ ] **GREEN**: Update Boundary declarations in these 5 files:
  - `apps/jarga/lib/projects.ex` — line 19: remove `Identity.Repo` from deps
  - `apps/jarga/lib/notes.ex` — line 21: remove `Identity.Repo` from deps
  - `apps/jarga/lib/documents.ex` — line 18: remove `Identity.Repo` from deps
  - `apps/jarga/lib/documents/infrastructure.ex` — line 40: remove `Identity.Repo` from deps
  - `apps/jarga/lib/documents/notes/infrastructure.ex` — line 33: remove `Identity.Repo` from deps
- [ ] **REFACTOR**: Verify `mix boundary` passes with no new violations

### Step 1.2: Update Repo Aliases in Production Files (6 repository/context files)

Change `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo` in all production files.

- [ ] **RED**: Write a verification test (or use existing tests) that exercises code paths through each affected module. Confirm all pass before changes.
- [ ] **GREEN**: Update the `alias Identity.Repo, as: Repo` line in these 6 files:
  1. `apps/jarga/lib/projects.ex` — line 32: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  2. `apps/jarga/lib/notes.ex` — line 28: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  3. `apps/jarga/lib/documents.ex` — line 35: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  4. `apps/jarga/lib/projects/infrastructure/repositories/authorization_repository.ex` — line 15: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  5. `apps/jarga/lib/projects/infrastructure/repositories/project_repository.ex` — line 19: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  6. `apps/jarga/lib/documents/infrastructure/repositories/document_repository.ex` — line 17: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`

- [ ] **RED (continued)**: Update these 2 additional files:
  7. `apps/jarga/lib/documents/infrastructure/repositories/authorization_repository.ex` — line 13: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  8. `apps/jarga/lib/documents/notes/infrastructure/repositories/authorization_repository.ex` — line 11: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`

- [ ] **GREEN (continued)**: Update these 2 additional files:
  9. `apps/jarga/lib/documents/notes/infrastructure/repositories/note_repository.ex` — line 9: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`

- [ ] **REFACTOR**: Run `mix compile --warnings-as-errors` — confirm no warnings

### Phase 1 Validation

- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` passes (no new violations)
- [ ] `mix test` passes in `apps/jarga` — all 604 tests pass
- [ ] Commit: "refactor: Switch Jarga production code from Identity.Repo to Jarga.Repo"

---

## Phase 2: Replace belongs_to with Plain Fields

**Goal:** Remove all `belongs_to` associations to Identity schemas and replace with plain `field(:x, :binary_id)` declarations. Follow Chat's precedent (`apps/chat/lib/chat/infrastructure/schemas/session_schema.ex`).

### Step 2.1: Update ProjectSchema (2 associations)

- [ ] **RED**: Run existing project tests to establish baseline: `mix test apps/jarga/test/projects/`
- [ ] **GREEN**: Update `apps/jarga/lib/projects/infrastructure/schemas/project_schema.ex`:
  - Line 29: `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` → `field(:user_id, :binary_id)`
  - Line 30: `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema)` → `field(:workspace_id, :binary_id)`
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/projects/` — all tests pass

### Step 2.2: Update DocumentSchema (3 associations)

- [ ] **RED**: Run existing document tests to establish baseline: `mix test apps/jarga/test/documents/`
- [ ] **GREEN**: Update `apps/jarga/lib/documents/infrastructure/schemas/document_schema.ex`:
  - Line 21: `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` → `field(:user_id, :binary_id)`
  - Line 23: `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema, type: Ecto.UUID)` → `field(:workspace_id, :binary_id)`
  - Lines 27-29: `belongs_to(:created_by_user, Identity.Infrastructure.Schemas.UserSchema, foreign_key: :created_by)` → `field(:created_by, :binary_id)`
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/documents/` — all tests pass

### Step 2.3: Update NoteSchema (2 associations)

- [ ] **RED**: Run existing note tests to establish baseline: `mix test apps/jarga/test/documents/notes/`
- [ ] **GREEN**: Update `apps/jarga/lib/documents/notes/infrastructure/schemas/note_schema.ex`:
  - Line 17: `belongs_to(:user, Identity.Infrastructure.Schemas.UserSchema)` → `field(:user_id, :binary_id)`
  - Line 19: `belongs_to(:workspace, Identity.Infrastructure.Schemas.WorkspaceSchema, type: Ecto.UUID)` → `field(:workspace_id, :binary_id)`
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/documents/notes/` — all tests pass

### Phase 2 Validation

- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` passes
- [ ] `mix test` passes in `apps/jarga` — all 604 tests pass
- [ ] Commit: "refactor: Replace Identity belongs_to associations with plain fields in Jarga schemas"

---

## Phase 3: Replace Cross-Schema Joins with Identity Facade Calls

**Goal:** Remove all joins against Identity tables (`WorkspaceSchema`, `WorkspaceMemberSchema`) and replace with pre-query facade calls to `Identity.member?/2`. This cleanly separates the database boundary.

### Step 3.1: Refactor Projects Queries — `for_user/2`

**File:** `apps/jarga/lib/projects/infrastructure/queries/queries.ex`

The current `for_user/2` joins `WorkspaceSchema` and `WorkspaceMemberSchema` to filter projects by membership. After the refactor, callers will verify membership via Identity facade first, then pass a simple workspace-scoped query.

**Strategy:** The `for_user` function currently ensures the user is a member of the workspace. Since projects are always fetched with a `workspace_id` filter (see `list_projects_for_workspace/2` and `for_user_by_id/3`), the membership check can be done via `Identity.member?/2` at the context/use-case level before the query runs. However, `for_user` is also used standalone (e.g., `for_user_by_id` and `for_user_by_slug`). The safest refactoring approach is to replace the join-based filter with a subquery against the `workspace_members` table directly (since it's in the shared database), OR to restructure callers.

**Recommended approach:** Since both repos share the same database, the most pragmatic and least disruptive approach is to replace the Identity schema aliases with direct `from` clauses against the raw tables. This eliminates the schema coupling while keeping the query semantics identical. The workspace_members table is in the same database — we just stop referencing Identity's Ecto schema modules.

- [ ] **RED**: Write/run tests that exercise `for_user/2`:
  - `apps/jarga/test/projects/infrastructure/queries/queries_test.exs` (if exists, use it; if not, the existing integration tests via `projects_test.exs` serve as regression)
  - Run `mix test apps/jarga/test/projects/` to establish baseline
- [ ] **GREEN**: Update `apps/jarga/lib/projects/infrastructure/queries/queries.ex`:
  - Remove line 13: `alias Identity.Infrastructure.Schemas.{WorkspaceSchema, WorkspaceMemberSchema}`
  - Rewrite `for_user/2` (lines 48-56) to use a raw table reference instead of Identity schemas:
    ```elixir
    def for_user(query \\ base(), %User{} = user) do
      from(p in query,
        join: wm in "workspace_members",
        on: wm.workspace_id == p.workspace_id and wm.user_id == ^user.id
      )
    end
    ```
    This queries the same table without referencing `Identity.Infrastructure.Schemas.WorkspaceMemberSchema`. The join through `WorkspaceSchema` is unnecessary — `workspace_members.workspace_id` directly matches `projects.workspace_id`.
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/projects/` — all tests pass

### Step 3.2: Refactor Document Queries — `viewable_by_user/2`

**File:** `apps/jarga/lib/documents/infrastructure/queries/document_queries.ex`

The current `viewable_by_user/2` left-joins `WorkspaceMemberSchema` to check workspace membership for public document visibility.

- [ ] **RED**: Run `mix test apps/jarga/test/documents/infrastructure/queries/document_queries_test.exs` to establish baseline
- [ ] **GREEN**: Update `apps/jarga/lib/documents/infrastructure/queries/document_queries.ex`:
  - Remove line 10: `alias Identity.Infrastructure.Schemas.WorkspaceMemberSchema`
  - Rewrite `viewable_by_user/2` (lines 37-44) to use raw table reference:
    ```elixir
    def viewable_by_user(query, %User{} = user) do
      user_id = user.id

      from([document: d] in query,
        left_join: wm in "workspace_members",
        on: wm.workspace_id == d.workspace_id and wm.user_id == ^user_id,
        where: d.user_id == ^user_id or (d.is_public == true and not is_nil(wm.id))
      )
    end
    ```
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/documents/infrastructure/queries/document_queries_test.exs` — all tests pass

### Step 3.3: Refactor Notes Authorization Repository — `verify_note_access_via_document/2`

**File:** `apps/jarga/lib/documents/notes/infrastructure/repositories/authorization_repository.ex`

The current `verify_note_access_via_document/2` left-joins `WorkspaceMemberSchema` to check workspace membership for document access.

- [ ] **RED**: Run `mix test apps/jarga/test/documents/notes/infrastructure/repositories/authorization_repository_test.exs` to establish baseline
- [ ] **GREEN**: Update `apps/jarga/lib/documents/notes/infrastructure/repositories/authorization_repository.ex`:
  - Remove line 17: `alias Identity.Infrastructure.Schemas.WorkspaceMemberSchema`
  - Rewrite the join in `verify_note_access_via_document/2` (lines 58-71) to use raw table reference:
    ```elixir
    def verify_note_access_via_document(%User{} = user, note_id) do
      query =
        from(n in NoteSchema,
          join: dc in DocumentComponentSchema,
          on: dc.component_id == n.id and dc.component_type == "note",
          join: d in DocumentSchema,
          on: d.id == dc.document_id,
          left_join: wm in "workspace_members",
          on: wm.workspace_id == d.workspace_id and wm.user_id == ^user.id,
          where: n.id == ^note_id,
          where: d.user_id == ^user.id or (d.is_public == true and not is_nil(wm.id)),
          select: n
        )

      case Repo.one(query) do
        nil ->
          if Repo.get(NoteSchema, note_id) do
            {:error, :unauthorized}
          else
            {:error, :note_not_found}
          end

        note ->
          {:ok, note}
      end
    end
    ```
- [ ] **REFACTOR**: Run `mix test apps/jarga/test/documents/notes/infrastructure/repositories/authorization_repository_test.exs` — all tests pass

### Step 3.4: Clean Up Remaining Identity Schema Aliases

After the join refactoring, verify no Identity infrastructure schema aliases remain in production code. The only remaining Identity references should be:
- `Identity` (the public facade module)
- `Identity.Domain.Entities.User` (exported entity, used in function signatures)

- [ ] **RED**: `grep -rn "Identity.Infrastructure.Schemas" apps/jarga/lib/` should return zero results
- [ ] **GREEN**: Remove any remaining aliases found
- [ ] **REFACTOR**: `mix compile --warnings-as-errors` passes

### Phase 3 Validation

- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` passes
- [ ] `mix test` passes in `apps/jarga` — all 604 tests pass
- [ ] No references to `Identity.Infrastructure.Schemas` remain in `apps/jarga/lib/`
- [ ] No references to `Identity.Repo` remain in `apps/jarga/lib/`
- [ ] Commit: "refactor: Replace cross-schema joins with raw table references in Jarga queries"

---

## Phase 4: Update Test Files

**Goal:** Update test files that alias `Identity.Repo, as: Repo` for Jarga-owned operations. Keep `Identity.Repo` references where they operate on Identity-owned data (users, tokens, workspace_members).

### Step 4.1: Update DataCase Default Alias

- [ ] **RED**: Note that `data_case.ex` line 32 aliases `Identity.Repo, as: Repo` — this is used as the default Repo alias in all test modules that `use Jarga.DataCase`.
- [ ] **GREEN**: Update `apps/jarga/test/support/data_case.ex`:
  - Line 32: `alias Identity.Repo, as: Repo` → `alias Jarga.Repo, as: Repo`
  - Update the comment on line 30-31 to reflect the change
- [ ] **REFACTOR**: This changes the default `Repo` in all tests from `Identity.Repo` to `Jarga.Repo`. Since both point to the same database, this is safe.

### Step 4.2: Update Test Files with Explicit Identity.Repo Aliases

These test files explicitly alias `Identity.Repo, as: Repo` for Jarga-owned operations. Update them to use `Jarga.Repo`.

- [ ] **RED**: Run `mix test` in `apps/jarga` to establish baseline
- [ ] **GREEN**: Update these test files:
  1. `apps/jarga/test/accounts_test.exs` — line 6: `alias Identity.Repo` — **KEEP THIS ONE**. This file tests Jarga.Accounts which delegates to Identity. The `Repo` reference here queries Identity-owned data (UserTokenSchema, UserSchema). It should stay as `Identity.Repo` since it's operating on Identity entities.
  2. `apps/jarga/test/documents/notes/infrastructure/repositories/authorization_repository_test.exs` — line 8: `alias Identity.Repo, as: Repo` → Remove this line (DataCase now provides `Jarga.Repo` as default `Repo`). The only `Repo.insert!()` calls in this file insert `DocumentComponentSchema` which is Jarga-owned.
  3. `apps/jarga/test/documents/notes/infrastructure/queries/queries_test.exs` — line 6: `alias Identity.Repo, as: Repo` → Remove this line (DataCase provides default)
  4. `apps/jarga/test/documents/infrastructure/queries/document_queries_test.exs` — line 7: `alias Identity.Repo, as: Repo` → Remove this line (DataCase provides default)
- [ ] **REFACTOR**: Run `mix test` in `apps/jarga` — all tests pass

### Step 4.3: Update TestUsers Module

- [ ] **RED**: Verify current tests pass
- [ ] **GREEN**: Update `apps/jarga/test/support/test_users.ex`:
  - Line 32 Boundary deps: Remove `Identity.Repo` (keep `Identity` and `Jarga.Repo`)
  - Line 41: `alias Identity.Repo, as: Repo` — **KEEP THIS ONE**. TestUsers operates on Identity-owned UserSchema data. It should stay as `Identity.Repo`.
- [ ] **REFACTOR**: Run `mix test` — confirm passes

### Step 4.4: Update SandboxHelper Boundary Deps

- [ ] **RED**: Verify current tests pass
- [ ] **GREEN**: Update `apps/jarga/test/support/sandbox_helper.ex`:
  - Line 16 Boundary deps: `Identity.Repo` should STAY in deps list — sandbox_helper legitimately needs to reference both repos for sandbox management
  - Line 21 `@repos` list: Both `Jarga.Repo` and `Identity.Repo` should STAY — needed for sandbox checkout
  - **No changes needed** to this file — it correctly manages sandboxes for all shared-database repos
- [ ] **REFACTOR**: Confirm no changes needed

### Step 4.5: Update projects_fixtures.ex

- [ ] **RED**: Verify current tests pass
- [ ] **GREEN**: Update `apps/jarga/test/support/fixtures/projects_fixtures.ex`:
  - Line 65: `Identity.Repo.insert!()` → `Jarga.Repo.insert!()` — This inserts a `ProjectSchema` which is Jarga-owned. Should use `Jarga.Repo`.
  - Add `alias Jarga.Repo` at the top of the module
- [ ] **REFACTOR**: Run `mix test` — confirm passes

### Step 4.6: Update Seed Files

- [ ] **RED**: Review seed file references
- [ ] **GREEN**: Update seed files — these are NOT production code and run outside the normal app lifecycle, but for consistency:
  - `apps/jarga/priv/repo/exo_seeds.exs`:
    - Line 22: `Identity.Repo.start_link()` — **KEEP** (needs both repos started)
    - Lines 78-85: TRUNCATE statements via `Identity.Repo` — These can stay as `Identity.Repo` OR switch to `Jarga.Repo` since both connect to the same DB. For consistency, change Jarga-owned table truncates to `Jarga.Repo`:
      - Lines 79-81 (document_components, documents, projects): Switch to `Jarga.Repo`
      - Lines 78, 82-85 (api_keys, workspace_members, workspaces, users_tokens, users): **KEEP as `Identity.Repo`** (Identity-owned tables)
    - Lines 113, 130-131, 151: `Identity.Repo.update!()` and `Identity.Repo.insert!()` for users, workspace_members, api_keys — **KEEP** (Identity-owned data)
  - `apps/jarga/priv/repo/exo_seeds_web.exs`:
    - Line 23: `Identity.Repo.start_link()` — **KEEP**
    - Lines 44-58: TRUNCATE statements — Apply same rule as above
    - Lines 82, 130-133, 251: Identity-owned operations — **KEEP**
- [ ] **REFACTOR**: Test seed scripts still work: `MIX_ENV=test mix run --no-start apps/jarga/priv/repo/exo_seeds.exs`

### Phase 4 Validation

- [ ] `mix compile --warnings-as-errors` passes
- [ ] `mix boundary` passes
- [ ] `mix test` passes in `apps/jarga` — all 604 tests pass
- [ ] Commit: "refactor: Update Jarga test files to use Jarga.Repo for Jarga-owned operations"

---

## Phase 5: Final Validation and Cleanup

### Step 5.1: Verify No Stale References

- [ ] **RED**: Run these verification commands:
  - `grep -rn "Identity.Repo" apps/jarga/lib/` → should return **zero results**
  - `grep -rn "Identity.Infrastructure.Schemas" apps/jarga/lib/` → should return **zero results**
  - `grep -rn "Identity.Repo" apps/jarga/test/` → should only return results in:
    - `test/support/data_case.ex` (sandbox checkout/allow/mode)
    - `test/support/sandbox_helper.ex` (sandbox management)
    - `test/test_helper.exs` (sandbox mode setup)
    - `test/accounts_test.exs` (Identity-owned queries)
    - `test/support/fixtures/accounts_fixtures.ex` (Identity-owned inserts)
    - `test/support/fixtures/workspaces_fixtures.ex` (Identity-owned inserts)
    - `test/support/test_users.ex` (Identity-owned operations)
  - `grep -rn "Identity.Repo" apps/jarga/priv/` → seed files only, for Identity-owned operations
- [ ] **GREEN**: Fix any stale references found
- [ ] **REFACTOR**: Clean up

### Step 5.2: Run Full Pre-commit Checks

- [ ] Run `mix precommit` in the umbrella root
- [ ] Run `mix boundary` — no violations
- [ ] Run `mix test` across the entire umbrella — confirm no regressions in other apps

### Step 5.3: Final Boundary Audit

Verify the Boundary declarations are correct post-refactoring:

**Production modules — should have `Jarga.Repo` but NOT `Identity.Repo`:**
- `apps/jarga/lib/projects.ex` — deps should include `Identity` (facade), `Jarga.Repo`, NOT `Identity.Repo`
- `apps/jarga/lib/notes.ex` — deps should include `Identity` (facade), `Jarga.Repo`, NOT `Identity.Repo`
- `apps/jarga/lib/documents.ex` — deps should include `Identity` (facade), `Jarga.Repo`, NOT `Identity.Repo`
- `apps/jarga/lib/documents/infrastructure.ex` — deps should include `Identity` (facade), `Jarga.Repo`, NOT `Identity.Repo`
- `apps/jarga/lib/documents/notes/infrastructure.ex` — deps should include `Identity` (facade), `Jarga.Repo`, NOT `Identity.Repo`

**Test modules — may legitimately reference both repos:**
- `test/support/sandbox_helper.ex` — `Identity.Repo` stays in deps (sandbox management)
- `test/support/data_case.ex` — `Jarga.Repo` as default, `Identity.Repo` stays for sandbox checkout
- `test/support/fixtures/accounts_fixtures.ex` — `Identity.Repo` stays (Identity-owned data)
- `test/support/fixtures/workspaces_fixtures.ex` — `Identity.Repo` stays (Identity-owned data)
- `test/support/test_users.ex` — `Identity.Repo` stays (Identity-owned data)

### Phase 5 Validation

- [ ] `mix precommit` passes
- [ ] `mix boundary` passes
- [ ] Full umbrella `mix test` passes
- [ ] Commit: "refactor: Final cleanup and verification of Jarga repo migration"

---

## Pre-Commit Checkpoint

After all phases are complete:

- [ ] `mix precommit` passes (compilation, boundary, format, credo, tests)
- [ ] `mix boundary` passes explicitly
- [ ] No `Identity.Repo` references in `apps/jarga/lib/`
- [ ] No `Identity.Infrastructure.Schemas` references in `apps/jarga/lib/`
- [ ] `Identity.Repo` only appears in test/seed files for Identity-owned data operations
- [ ] All 604 Jarga tests pass
- [ ] No regressions in other umbrella apps

---

## Testing Strategy

- **Total estimated tests**: 0 new tests (all existing 604 tests serve as regression suite)
- **Distribution**: This is a pure refactoring — all changes are validated by existing test coverage
- **Risk areas**:
  - Schema field declarations changing from `belongs_to` to `field` — could affect preload behavior if any code tries to preload `:user` or `:workspace` associations. Verify no preloads of Identity associations exist in Jarga code.
  - Query semantics must remain identical — the raw table reference `"workspace_members"` must produce the same SQL as the schema-based join.

## Change Summary by File

### Production Files Changed (11 files)

| File | Change |
|------|--------|
| `lib/projects.ex` | Remove `Identity.Repo` from Boundary deps; `alias Jarga.Repo, as: Repo` |
| `lib/notes.ex` | Remove `Identity.Repo` from Boundary deps; `alias Jarga.Repo, as: Repo` |
| `lib/documents.ex` | Remove `Identity.Repo` from Boundary deps; `alias Jarga.Repo, as: Repo` |
| `lib/documents/infrastructure.ex` | Remove `Identity.Repo` from Boundary deps |
| `lib/documents/notes/infrastructure.ex` | Remove `Identity.Repo` from Boundary deps |
| `lib/projects/infrastructure/schemas/project_schema.ex` | Replace 2 `belongs_to` with `field(:x, :binary_id)` |
| `lib/documents/infrastructure/schemas/document_schema.ex` | Replace 3 `belongs_to` with `field(:x, :binary_id)` |
| `lib/documents/notes/infrastructure/schemas/note_schema.ex` | Replace 2 `belongs_to` with `field(:x, :binary_id)` |
| `lib/projects/infrastructure/queries/queries.ex` | Remove Identity schema aliases; replace join with raw table reference |
| `lib/documents/infrastructure/queries/document_queries.ex` | Remove Identity schema alias; replace join with raw table reference |
| `lib/documents/notes/infrastructure/repositories/authorization_repository.ex` | Remove Identity schema alias; replace join with raw table reference; `alias Jarga.Repo` |

### Additional Production Files (Repo alias only, 3 files)

| File | Change |
|------|--------|
| `lib/projects/infrastructure/repositories/authorization_repository.ex` | `alias Jarga.Repo, as: Repo` |
| `lib/projects/infrastructure/repositories/project_repository.ex` | `alias Jarga.Repo, as: Repo` |
| `lib/documents/infrastructure/repositories/document_repository.ex` | `alias Jarga.Repo, as: Repo` |
| `lib/documents/infrastructure/repositories/authorization_repository.ex` | `alias Jarga.Repo, as: Repo` |
| `lib/documents/notes/infrastructure/repositories/note_repository.ex` | `alias Jarga.Repo, as: Repo` |

### Test Files Changed (5 files)

| File | Change |
|------|--------|
| `test/support/data_case.ex` | Change default `Repo` alias from `Identity.Repo` to `Jarga.Repo` |
| `test/documents/notes/infrastructure/repositories/authorization_repository_test.exs` | Remove explicit `Identity.Repo` alias (DataCase provides default) |
| `test/documents/notes/infrastructure/queries/queries_test.exs` | Remove explicit `Identity.Repo` alias |
| `test/documents/infrastructure/queries/document_queries_test.exs` | Remove explicit `Identity.Repo` alias |
| `test/support/fixtures/projects_fixtures.ex` | Change `Identity.Repo.insert!()` → `Jarga.Repo.insert!()` for ProjectSchema |

### Test Files NOT Changed (intentionally kept as-is)

| File | Reason |
|------|--------|
| `test/accounts_test.exs` | Queries Identity-owned UserSchema/UserTokenSchema |
| `test/support/fixtures/accounts_fixtures.ex` | Inserts Identity-owned users/tokens |
| `test/support/fixtures/workspaces_fixtures.ex` | Inserts Identity-owned workspace_members |
| `test/support/test_users.ex` | Manages Identity-owned UserSchema data |
| `test/support/sandbox_helper.ex` | Manages sandbox for all shared-DB repos |
| `test/test_helper.exs` | Sets sandbox mode for all repos |

### Seed Files (optional consistency changes)

| File | Change |
|------|--------|
| `priv/repo/exo_seeds.exs` | Switch Jarga-owned table TRUNCATEs to `Jarga.Repo` |
| `priv/repo/exo_seeds_web.exs` | Switch Jarga-owned table TRUNCATEs to `Jarga.Repo` |
