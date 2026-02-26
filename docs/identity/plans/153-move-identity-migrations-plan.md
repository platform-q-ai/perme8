# Feature: Move Identity-Related Database Migrations into the Identity App

**Ticket**: [#153](https://github.com/platform-q-ai/perme8/issues/153)
**Type**: Refactor (infrastructure ownership)
**Risk**: Medium — touches shared database schema, migration ordering, and release infrastructure

## Overview

All 19 database migrations currently live in `apps/jarga/priv/repo/migrations/`. Six of them create or alter identity-owned tables (`users`, `users_tokens`, `workspaces`, `workspace_members`, `workspace_invitations`, `api_keys`, `workspace_role` enum). This plan moves identity-related schema definitions into `apps/identity/priv/repo/migrations/` so the identity app owns its own database schema, per the [App Ownership Registry](../../app_ownership.md).

**Strategy**: New idempotent migrations in Identity using `IF NOT EXISTS` / `IF EXISTS` guards. This means:
- On existing databases (where Jarga already ran), identity migrations safely skip (tables already exist).
- On fresh databases, identity migrations create everything needed.
- No `schema_migrations` conflicts since identity migrations get new timestamps and are tracked by `Identity.Repo`.
- Original Jarga migrations remain unchanged (no risk to existing deployments).

## UI Strategy

- **LiveView coverage**: N/A — no UI changes
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `identity` (infrastructure layer only — migrations)
- **Dependencies**: `jarga` (original migrations stay, but mixed migrations no longer create identity tables on fresh DBs — identity does)
- **Exported schemas**: None changed
- **New context needed?**: No

## Pre-Implementation Baseline

| App | Tests | Failures |
|-----|-------|----------|
| identity | 531 | 0 |
| jarga | 871 | 0 |
| agents | — | 0 |
| jarga_web | — | 0 |

Run: `mix test` from umbrella root to establish baseline before any changes.

---

## Phase 1: Test Infrastructure & Identity.Release Module

This phase creates the `Identity.Release` module and verifies the migration infrastructure works correctly. Since this is a refactor of existing infrastructure (not new domain logic), we don't have a traditional Domain/Application split — we go straight to infrastructure.

### Step 1.1: Create Identity.Release Module

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/release_test.exs`
  - Tests:
    - `Identity.Release.migrate/0` exists and is callable
    - `Identity.Release.rollback/2` exists and is callable
    - `repos/0` returns `[Identity.Repo]`
  - Note: These are lightweight tests that verify the module structure, not actual migration execution (that's integration-tested in Phase 3).

- [ ] ⏸ **GREEN**: Implement `apps/identity/lib/identity/release.ex`
  ```elixir
  defmodule Identity.Release do
    @moduledoc """
    Used for executing DB release tasks when run in production without Mix installed.
    """

    @app :identity

    def migrate do
      load_app()

      for repo <- repos() do
        {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
      end
    end

    def rollback(repo, version) do
      load_app()
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
    end

    def repos do
      Application.fetch_env!(@app, :ecto_repos)
    end

    defp load_app do
      Application.ensure_all_started(:ssl)
      Application.ensure_loaded(@app)
    end
  end
  ```

- [ ] ⏸ **REFACTOR**: Ensure module follows same pattern as `JargaWeb.Release` but is self-contained for Identity.

### Phase 1 Validation

- [ ] ⏸ `Identity.Release` test passes
- [ ] ⏸ `mix compile --warnings-as-errors` passes from umbrella root
- [ ] ⏸ No boundary violations

---

## Phase 2: Identity-Owned Migrations

Create new migrations in `apps/identity/priv/repo/migrations/` that idempotently create all identity-owned tables. These use timestamps that sort BEFORE the original Jarga migrations to establish correct ordering on fresh databases.

### Migration Ordering Strategy

Identity migrations must run before Jarga's because Jarga tables (`projects`, `notes`, etc.) have foreign keys to identity tables (`users`, `workspaces`). We use timestamps from **2025-10-01** (before the first Jarga migration `20251103145700`):

| New Identity Migration | Creates | Timestamp |
|------------------------|---------|-----------|
| `create_identity_schema` | `workspace_role` enum, `users`, `workspaces`, `workspace_members`, `workspace_invitations` | `20251001000000` |
| `create_users_auth_tables` | `citext` extension, alters `users` (rename `password_hash`, add `confirmed_at`), creates `users_tokens` | `20251001000001` |
| `add_slug_to_workspaces` | Adds `slug` column to `workspaces` with unique index | `20251001000002` |
| `add_workspace_members_composite_index` | Adds composite index `[:workspace_id, :user_id]` on `workspace_members` | `20251001000003` |
| `add_user_preferences` | Adds `preferences` jsonb column to `users` with GIN index | `20251001000004` |
| `create_api_keys` | Creates `api_keys` table | `20251001000005` |

### Step 2.1: Create Migration Directory

- [ ] ⏸ Create `apps/identity/priv/repo/migrations/` directory

### Step 2.2: Migration — Create Identity Schema (MIXED split from `20251103145700`)

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/infrastructure/migrations/create_identity_schema_test.exs`
  - Tests:
    - `workspace_role` enum type exists in the database
    - `users` table exists with expected columns (`id`, `first_name`, `last_name`, `email`, `password_hash`, `role`, `date_created`, `last_login`, `status`, `avatar_url`)
    - `workspaces` table exists with expected columns (`id`, `name`, `description`, `color`, `is_archived`, `slug`, `inserted_at`, `updated_at`)
    - `workspace_members` table exists with expected columns and foreign keys
    - `workspace_invitations` table exists with expected columns
    - Unique index exists on `users.email`
    - Unique index exists on `workspace_members[:workspace_id, :email]`
    - Standard indexes exist on `workspace_members` and `workspace_invitations`
  - Note: These tests validate the database state (table/column existence), not migration execution. Use raw SQL queries against `Identity.Repo` to verify. They pass on the existing database because Jarga already created these tables.

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000000_create_identity_schema.exs`
  - Module: `Identity.Repo.Migrations.CreateIdentitySchema`
  - Use `def up do ... end` and `def down do ... end` (not `change`)
  - All table creates use `create_if_not_exists` / `execute ... IF NOT EXISTS`
  - All index creates use `create_if_not_exists`
  - Identity tables only: `users`, `workspaces`, `workspace_members`, `workspace_invitations`, `workspace_role` enum
  - Does NOT include `projects`, `notes`, `pages`, `sheets`, etc. (those stay in Jarga)
  - `down` uses `drop_if_exists`

- [ ] ⏸ **REFACTOR**: Verify idempotency — running migration on existing DB does nothing harmful.

### Step 2.3: Migration — Create Users Auth Tables (PURE IDENTITY from `20251103145740`)

- [ ] ⏸ **RED**: Write test (extend `create_identity_schema_test.exs` or new file `apps/identity/test/identity/infrastructure/migrations/create_users_auth_tables_test.exs`)
  - Tests:
    - `users.hashed_password` column exists (renamed from `password_hash`)
    - `users.confirmed_at` column exists
    - `users_tokens` table exists with expected columns
    - Unique index on `users_tokens[:context, :token]`
    - Index on `users_tokens[:user_id]`
    - `citext` extension is installed

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000001_create_users_auth_tables.exs`
  - Module: `Identity.Repo.Migrations.CreateUsersAuthTables`
  - Use `def change do ... end` with idempotent SQL
  - Mirrors the logic from `Jarga.Repo.Migrations.CreateUsersAuthTables` but with `IF NOT EXISTS` / `IF EXISTS` guards
  - Extension: `CREATE EXTENSION IF NOT EXISTS citext`
  - Column rename: guarded with `IF EXISTS` / `IF NOT EXISTS` checks
  - Add `confirmed_at`: guarded with `IF NOT EXISTS`
  - Create `users_tokens`: use `create_if_not_exists`

- [ ] ⏸ **REFACTOR**: Ensure reversibility is maintained (down path handles both fresh and existing databases).

### Step 2.4: Migration — Add Slug to Workspaces (MIXED split from `20251104172610`)

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/infrastructure/migrations/add_slug_to_workspaces_test.exs`
  - Tests:
    - `workspaces.slug` column exists and is not nullable
    - Unique index on `workspaces[:slug]` exists

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000002_add_slug_to_workspaces.exs`
  - Module: `Identity.Repo.Migrations.AddSlugToWorkspaces`
  - Use `def up do ... end` / `def down do ... end`
  - Add `slug` column to `workspaces` only IF it doesn't exist (guard with raw SQL check)
  - Backfill existing slugs (only if column was just added, i.e., fresh DB)
  - Make non-nullable (only if column was just added)
  - Create unique index with `create_if_not_exists`
  - Does NOT touch `projects.slug` (that stays in Jarga)

- [ ] ⏸ **REFACTOR**: Clean up.

### Step 2.5: Migration — Add Workspace Members Composite Index (MIXED split from `20251105005400`)

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/infrastructure/migrations/add_workspace_members_composite_index_test.exs`
  - Tests:
    - Composite index on `workspace_members[:workspace_id, :user_id]` exists

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000003_add_workspace_members_composite_index.exs`
  - Module: `Identity.Repo.Migrations.AddWorkspaceMembersCompositeIndex`
  - Use `def change do ... end`
  - `create_if_not_exists index(:workspace_members, [:workspace_id, :user_id])`
  - Does NOT include `pages` indexes (those stay in Jarga)

- [ ] ⏸ **REFACTOR**: Clean up.

### Step 2.6: Migration — Add User Preferences (MIXED split from `20251120175234`)

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/infrastructure/migrations/add_user_preferences_test.exs`
  - Tests:
    - `users.preferences` column exists and is `jsonb`
    - GIN index on `users[:preferences]` exists

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000004_add_user_preferences.exs`
  - Module: `Identity.Repo.Migrations.AddUserPreferences`
  - Use `def change do ... end`
  - Guard: Only add column if it doesn't exist (raw SQL check)
  - `create_if_not_exists index(:users, [:preferences], using: :gin)`
  - Does NOT include `agents` or `workspace_agents` tables (those belong to agents app)

- [ ] ⏸ **REFACTOR**: Clean up.

### Step 2.7: Migration — Create API Keys (PURE IDENTITY from `20260105120000`)

- [ ] ⏸ **RED**: Write test `apps/identity/test/identity/infrastructure/migrations/create_api_keys_test.exs`
  - Tests:
    - `api_keys` table exists with expected columns
    - Index on `api_keys[:user_id]` exists
    - Unique index on `api_keys[:hashed_token]` exists

- [ ] ⏸ **GREEN**: Create `apps/identity/priv/repo/migrations/20251001000005_create_api_keys.exs`
  - Module: `Identity.Repo.Migrations.CreateApiKeys`
  - Use `def change do ... end`
  - `create_if_not_exists table(:api_keys, ...)` with all columns
  - `create_if_not_exists index(...)` for both indexes

- [ ] ⏸ **REFACTOR**: Clean up.

### Phase 2 Validation

- [ ] ⏸ All migration structure tests pass against existing database
- [ ] ⏸ `mix ecto.migrate --app identity` runs successfully (all migrations skip on existing DB)
- [ ] ⏸ Identity tests still pass: 531 tests, 0 failures
- [ ] ⏸ Jarga tests still pass: 871 tests, 0 failures
- [ ] ⏸ Full test suite passes: `mix test`

---

## Phase 3: Update Release & Deployment Infrastructure

### Step 3.1: Update Migration Ordering in JargaWeb.Release

- [ ] ⏸ **RED**: Write test `apps/jarga_web/test/jarga_web/release_test.exs` (or update existing)
  - Tests:
    - `JargaWeb.Release.migrate/0` processes identity BEFORE jarga (flip `@apps` order)
    - The `@apps` list is `[:identity, :jarga]`
  - Note: If no existing test file, create one that validates the ordering.

- [ ] ⏸ **GREEN**: Update `apps/jarga_web/lib/jarga_web/release.ex`
  - Change `@apps [:jarga, :identity]` to `@apps [:identity, :jarga]`
  - This ensures Identity tables exist before Jarga attempts to create foreign keys to them on fresh databases.

- [ ] ⏸ **REFACTOR**: Clean up.

### Step 3.2: Create Identity.Release Module (if not done in Phase 1)

Already handled in Step 1.1. Verify it works for standalone migration:

- [ ] ⏸ Verify `Identity.Release.migrate/0` runs identity migrations independently

### Step 3.3: Update Release Overlay Scripts

- [ ] ⏸ **RED**: Verify current `rel/overlays/bin/migrate` calls `JargaWeb.Release.migrate` (already does — no change needed if ordering fix in Step 3.1 is sufficient)
  - Decision: The existing script calls `JargaWeb.Release.migrate` which already iterates both repos. After the ordering fix, this is correct.

- [ ] ⏸ **GREEN**: No change needed to `rel/overlays/bin/migrate` or `rel/overlays/bin/migrate.bat` — `JargaWeb.Release.migrate` already handles both apps.
  - **Alternative**: If we want Identity to be independently deployable in the future, we could update the script to call both `Identity.Release.migrate` and then `JargaWeb.Release.migrate`. For now, the existing approach is sufficient.

- [ ] ⏸ **REFACTOR**: Document the migration order dependency.

### Step 3.4: Update Identity mix.exs Aliases

- [ ] ⏸ **RED**: Verify `mix test --app identity` works with the new migrations
  - Currently Identity's `mix.exs` has no `ecto.setup`/`ecto.migrate` aliases
  - Tests rely on the umbrella-level or Jarga's migration running first

- [ ] ⏸ **GREEN**: Update `apps/identity/mix.exs` aliases to include:
  ```elixir
  defp aliases do
    [
      setup: ["deps.get", "ecto.setup"],
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"],
      precommit: ["compile --warnings-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
  ```

- [ ] ⏸ **REFACTOR**: Ensure the test alias properly creates and migrates before running tests.

### Phase 3 Validation

- [ ] ⏸ `JargaWeb.Release.migrate/0` processes identity first, then jarga
- [ ] ⏸ `mix ecto.migrate --app identity` succeeds
- [ ] ⏸ `mix ecto.migrate --app jarga` succeeds (after identity)
- [ ] ⏸ `rel/overlays/bin/migrate` calls `JargaWeb.Release.migrate` (unchanged)
- [ ] ⏸ Identity test suite: 531+ tests, 0 failures
- [ ] ⏸ Jarga test suite: 871 tests, 0 failures

---

## Phase 4: Fresh Database Verification

This phase verifies that a completely fresh database can be set up with identity migrations running first, followed by jarga migrations, with no errors.

### Step 4.1: Fresh Database Integration Test

- [ ] ⏸ **RED**: Create a manual test script or CI step that:
  1. Drops the test database
  2. Creates a fresh database
  3. Runs `mix ecto.migrate --app identity`
  4. Runs `mix ecto.migrate --app jarga`
  5. Verifies all tables exist
  6. Runs full test suite

- [ ] ⏸ **GREEN**: Execute the verification:
  ```bash
  # From umbrella root
  MIX_ENV=test mix ecto.drop --app jarga --app identity
  MIX_ENV=test mix ecto.create --app jarga --app identity
  MIX_ENV=test mix ecto.migrate --app identity
  MIX_ENV=test mix ecto.migrate --app jarga
  mix test
  ```

- [ ] ⏸ **REFACTOR**: Document the fresh setup procedure in the PR description.

### Step 4.2: Idempotency Verification

- [ ] ⏸ Run identity migrations twice — second run should be a no-op
- [ ] ⏸ Run jarga migrations after identity — should succeed without errors
- [ ] ⏸ Verify no duplicate tables, columns, or indexes

### Phase 4 Validation

- [ ] ⏸ Fresh database setup succeeds with identity-first ordering
- [ ] ⏸ All migrations are idempotent (re-runnable without error)
- [ ] ⏸ Full test suite passes on fresh database
- [ ] ⏸ Identity: 531+ tests, 0 failures
- [ ] ⏸ Jarga: 871 tests, 0 failures

---

## Pre-Commit Checkpoint

Before creating the PR, run:

```bash
mix precommit
mix boundary
```

- [ ] ⏸ `mix precommit` passes (compilation, formatting, credo, tests)
- [ ] ⏸ `mix boundary` shows no new violations
- [ ] ⏸ No regression in test counts

---

## Files Changed Summary

### New Files

| File | Purpose |
|------|---------|
| `apps/identity/lib/identity/release.ex` | Identity release module for production migrations |
| `apps/identity/test/identity/release_test.exs` | Tests for Identity.Release |
| `apps/identity/priv/repo/migrations/20251001000000_create_identity_schema.exs` | Idempotent: enum, users, workspaces, workspace_members, workspace_invitations |
| `apps/identity/priv/repo/migrations/20251001000001_create_users_auth_tables.exs` | Idempotent: citext, users auth columns, users_tokens |
| `apps/identity/priv/repo/migrations/20251001000002_add_slug_to_workspaces.exs` | Idempotent: workspaces.slug column + unique index |
| `apps/identity/priv/repo/migrations/20251001000003_add_workspace_members_composite_index.exs` | Idempotent: workspace_members composite index |
| `apps/identity/priv/repo/migrations/20251001000004_add_user_preferences.exs` | Idempotent: users.preferences column + GIN index |
| `apps/identity/priv/repo/migrations/20251001000005_create_api_keys.exs` | Idempotent: api_keys table + indexes |
| `apps/identity/test/identity/infrastructure/migrations/create_identity_schema_test.exs` | DB structure verification tests |
| `apps/identity/test/identity/infrastructure/migrations/create_users_auth_tables_test.exs` | DB structure verification tests |
| `apps/identity/test/identity/infrastructure/migrations/add_slug_to_workspaces_test.exs` | DB structure verification tests |
| `apps/identity/test/identity/infrastructure/migrations/add_workspace_members_composite_index_test.exs` | DB structure verification tests |
| `apps/identity/test/identity/infrastructure/migrations/add_user_preferences_test.exs` | DB structure verification tests |
| `apps/identity/test/identity/infrastructure/migrations/create_api_keys_test.exs` | DB structure verification tests |

### Modified Files

| File | Change |
|------|--------|
| `apps/jarga_web/lib/jarga_web/release.ex` | Flip `@apps` from `[:jarga, :identity]` to `[:identity, :jarga]` |
| `apps/identity/mix.exs` | Add `ecto.setup`, `ecto.reset`, and `test` aliases with migration steps |

### Unchanged Files (explicitly)

| File | Why |
|------|-----|
| All 19 Jarga migrations | Original migrations stay — backward compatibility for existing deployments |
| `rel/overlays/bin/migrate` | Already calls `JargaWeb.Release.migrate` which handles both apps |
| `rel/overlays/bin/migrate.bat` | Same as above |
| `config/config.exs` | Identity.Repo already configured with `ecto_repos: [Identity.Repo]` |
| `config/test.exs` | Identity.Repo already has sandbox config |
| `config/dev.exs` | Identity.Repo already has dev config |
| `config/runtime.exs` | Identity.Repo already has runtime config |

---

## Testing Strategy

- **Total estimated new tests**: ~20-25
- **Distribution**:
  - Infrastructure (migration structure verification): ~18-22 tests
  - Release module: ~3 tests
- **Existing test regression**: 0 failures expected (all changes are additive/idempotent)
- **Integration verification**: Fresh database setup + full suite run

### Migration Test Pattern

Each migration test verifies database state using raw SQL queries through `Identity.Repo`:

```elixir
defmodule Identity.Infrastructure.Migrations.CreateIdentitySchemaTest do
  use Identity.DataCase, async: false

  describe "identity schema" do
    test "workspace_role enum type exists" do
      result = Identity.Repo.query!("SELECT 1 FROM pg_type WHERE typname = 'workspace_role'")
      assert length(result.rows) == 1
    end

    test "users table exists with expected columns" do
      result = Identity.Repo.query!("""
        SELECT column_name FROM information_schema.columns
        WHERE table_name = 'users'
        ORDER BY ordinal_position
      """)
      columns = Enum.map(result.rows, &hd/1)
      assert "id" in columns
      assert "email" in columns
      assert "first_name" in columns
      # ...
    end
  end
end
```

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Migration runs on existing DB and duplicates tables | All DDL uses `IF NOT EXISTS` / `IF EXISTS` guards |
| Migration ordering wrong on fresh DB (Jarga FK fails) | Identity timestamps (`20251001*`) sort before Jarga (`20251103*`); `@apps` order flipped to `[:identity, :jarga]` |
| `schema_migrations` conflict (same version in two repos) | New timestamps for identity migrations — no overlap with Jarga's |
| Existing test suite breaks | Migrations are purely additive; existing Jarga migrations unchanged |
| Production deployment breaks | `JargaWeb.Release.migrate` still handles both; identity migrations skip on existing DB |
| Identity app can't migrate independently | `Identity.Release.migrate/0` + mix aliases enable standalone operation |

---

## Decision Log

| Decision | Rationale |
|----------|-----------|
| Use `IF NOT EXISTS` guards instead of moving migrations | Avoids `schema_migrations` conflicts; safe for existing deployments |
| Keep original Jarga migrations unchanged | Zero risk to existing databases; Jarga migrations become redundant for identity tables but harmless |
| Timestamps before Jarga's first migration | Ensures correct ordering on fresh databases via Ecto's timestamp-based migration sorting |
| Flip `@apps` order in `JargaWeb.Release` | Identity must create tables before Jarga adds foreign keys to them |
| `workspace_invitations` included in identity | Table is identity-owned (workspace membership domain) even though no schema exists yet |
| `agents`/`workspace_agents` tables NOT included | Owned by agents app, not identity — despite being in same mixed migration |
| `projects.slug` NOT included | Projects are Jarga-owned; only `workspaces.slug` moves to identity |
