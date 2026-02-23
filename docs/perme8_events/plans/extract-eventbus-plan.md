# Feature: Extract Perme8.Events Eventbus into Standalone Umbrella App

**Ticket**: #200
**Type**: Structural refactor (CRUD Update)

## Overview

Extract the `Perme8.Events` event infrastructure from `jarga` (and the `DomainEvent` macro from `identity`) into a new dedicated umbrella app called `perme8_events`. This eliminates the cyclic dependency that currently forces `DomainEvent` to live in `identity` and makes the event system a proper shared infrastructure layer at the bottom of the dependency graph.

**Key constraint**: All module names (`Perme8.Events`, `Perme8.Events.EventBus`, etc.) remain identical. Only the hosting app and the PubSub server name change.

## UI Strategy

- **LiveView coverage**: N/A (infrastructure-only change, no UI)
- **TypeScript needed**: None

## Affected Boundaries

- **Primary context**: `Perme8.Events` (moves from jarga/identity to perme8_events)
- **Dependencies**: None (perme8_events is a leaf node — depends on nothing in the umbrella)
- **Exported modules**: `Perme8.Events.EventBus`, `Perme8.Events.EventHandler`, `Perme8.Events.TestEventBus`, `Perme8.Events.DomainEvent`
- **New app needed?**: Yes — `apps/perme8_events/` (plain Elixir app with `--sup`)

## Dependency Graph After Extraction

```
  perme8_events (standalone — depends on nothing in umbrella)
      ^      ^       ^
      |      |       |
  identity  agents  entity_relationship_manager
      ^       ^
      |       |
    jarga ----+
     ^  ^     ^  ^
    /   |    /   |
  jarga_web  jarga_api  agents_web  agents_api
```

## PubSub Rename Strategy

The PubSub server name changes from `Jarga.PubSub` to `Perme8.Events.PubSub` across the entire codebase. The PubSub process moves from `Jarga.Application` supervision to `Perme8Events.Application`.

The new app reads the name from config: `Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub)`.

---

## Phase 1: Create New App Skeleton + Move Pure Modules (no PubSub dependency)

This phase creates the new umbrella app and moves modules that have **no** `Jarga.PubSub` dependency: `DomainEvent` and `TestEventBus`. Tests for these modules already use `ExUnit.Case, async: true` and need no PubSub.

### Step 1.1: Generate the new umbrella app

- [ ] ⏸ Create `apps/perme8_events` using `mix new perme8_events --sup` from `apps/` directory
- [ ] ⏸ Configure `apps/perme8_events/mix.exs`:
  - Add `boundary: boundary()` to project config
  - Add `compilers: [:boundary] ++ Mix.compilers()` to project config
  - Add `{:boundary, "~> 0.10", runtime: false}` to deps
  - Add `{:phoenix_pubsub, "~> 2.1"}` to deps (needed by EventBus/EventHandler/facade)
  - Add `{:ecto, "~> 3.12"}` to deps (needed by DomainEvent for `Ecto.UUID.generate()`)
  - Set `elixirc_paths(:test)` to `["lib", "test/support"]`
  - Set `elixirc_paths(_)` to `["lib"]`
  - Add boundary config with `externals_mode: :relaxed`

### Step 1.2: Move DomainEvent (pure macro, no PubSub)

- [ ] ⏸ **RED**: Create test `apps/perme8_events/test/perme8_events/domain_event_test.exs`
  - Copy from `apps/jarga/test/perme8_events/domain_event_test.exs`
  - Change `use ExUnit.Case, async: true` (already correct)
  - No other changes needed — tests use no PubSub or DataCase
  - Tests: struct definition, enforce_keys, new/1, event_type/0, aggregate_type/0
- [ ] ⏸ **GREEN**: Move `apps/identity/lib/perme8_events/domain_event.ex` to `apps/perme8_events/lib/perme8_events/domain_event.ex`
  - Keep module name `Perme8.Events.DomainEvent` unchanged
  - Keep existing `use Boundary` declaration
  - Update `@moduledoc` to remove "Lives in identity app" references
- [ ] ⏸ **REFACTOR**: Remove the original file from `apps/identity/lib/perme8_events/domain_event.ex`
- [ ] ⏸ **VERIFY**: Run `mix test apps/perme8_events/test/perme8_events/domain_event_test.exs` — all tests pass

### Step 1.3: Move TestEventBus (pure Agent, no PubSub)

- [ ] ⏸ **RED**: Create test `apps/perme8_events/test/perme8_events/test_event_bus_test.exs`
  - Copy from `apps/jarga/test/perme8_events/test_event_bus_test.exs`
  - Change to `use ExUnit.Case, async: true` (already correct)
  - Tests: start_link, emit/2, emit_all/2, get_events/1, reset/1
- [ ] ⏸ **GREEN**: Move `apps/jarga/lib/perme8_events/test_event_bus.ex` to `apps/perme8_events/lib/perme8_events/test_event_bus.ex`
  - Keep module name `Perme8.Events.TestEventBus` unchanged
  - No code changes needed — no PubSub references
- [ ] ⏸ **REFACTOR**: Remove `apps/jarga/lib/perme8_events/test_event_bus.ex` and `apps/jarga/test/perme8_events/test_event_bus_test.exs`
- [ ] ⏸ **VERIFY**: Run `mix test apps/perme8_events/test/perme8_events/test_event_bus_test.exs` — all tests pass

### Phase 1 Validation

- [ ] ⏸ `mix test apps/perme8_events` — DomainEvent + TestEventBus tests pass
- [ ] ⏸ `mix compile --warnings-as-errors` — no warnings from perme8_events app
- [ ] ⏸ Old tests in jarga/identity that reference these modules still compile (modules now come from perme8_events via umbrella deps — jarga depends on identity which... actually at this point we haven't added deps yet, so we need to ensure identity still compiles)

**IMPORTANT**: After removing `domain_event.ex` from identity, identity's mix.exs needs `{:perme8_events, in_umbrella: true}` so that modules using `use Perme8.Events.DomainEvent` can still resolve it. Similarly, jarga's mix.exs needs the dep too. Add these deps as part of this phase.

### Step 1.4: Update mix.exs deps for identity and jarga

- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/identity/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/jarga/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to boundary `check.apps` in `apps/identity/mix.exs`
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to boundary `check.apps` in `apps/jarga/mix.exs`
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` — identity and jarga still compile

---

## Phase 2: Move PubSub-Dependent Modules + Rename PubSub

This phase moves the remaining modules (`Perme8.Events` facade, `EventBus`, `EventHandler`), renames `Jarga.PubSub` to `Perme8.Events.PubSub` everywhere, and moves PubSub supervision.

### Step 2.1: Create Perme8Events.Application supervisor

- [ ] ⏸ **RED**: Write test `apps/perme8_events/test/perme8_events/application_test.exs`
  - Verify `Perme8.Events.PubSub` process is running after application start
  - `use ExUnit.Case` (the application is already started by the test runner)
  - Test: `assert Process.whereis(Perme8.Events.PubSub) != nil` or equivalent PubSub liveness check
- [ ] ⏸ **GREEN**: Create `apps/perme8_events/lib/perme8_events/application.ex`
  - Module: `Perme8Events.Application`
  - `use Application`
  - Children: `[{Phoenix.PubSub, name: pubsub_name()}]`
  - `defp pubsub_name, do: Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub)`
- [ ] ⏸ **REFACTOR**: Ensure `apps/perme8_events/mix.exs` sets `mod: {Perme8Events.Application, []}`

### Step 2.2: Add config for the new PubSub name

- [ ] ⏸ Add to `config/config.exs`:
  ```elixir
  # Perme8 Events shared PubSub
  config :perme8_events, pubsub: Perme8.Events.PubSub
  ```
- [ ] ⏸ **VERIFY**: Application starts and PubSub is supervised

### Step 2.3: Move EventBus (PubSub-dependent)

- [ ] ⏸ **RED**: Create test `apps/perme8_events/test/perme8_events/event_bus_test.exs`
  - Adapt from `apps/jarga/test/perme8_events/event_bus_test.exs`
  - Change `use Jarga.DataCase, async: false` to `use ExUnit.Case, async: false` (the EventBus tests only need PubSub, not Ecto; PubSub is started by Perme8Events.Application)
  - Replace all `Phoenix.PubSub.subscribe(Jarga.PubSub, ...)` with `Phoenix.PubSub.subscribe(Perme8.Events.PubSub, ...)`
  - Replace all `Phoenix.PubSub.broadcast(Jarga.PubSub, ...)` with `Phoenix.PubSub.broadcast(Perme8.Events.PubSub, ...)`
  - Tests: emit to context topic, aggregate topic, workspace topic, user topic; emit_all; skips nil workspace/user
- [ ] ⏸ **GREEN**: Move `apps/jarga/lib/perme8_events/event_bus.ex` to `apps/perme8_events/lib/perme8_events/event_bus.ex`
  - Replace `@pubsub Jarga.PubSub` with `@pubsub Application.compile_env(:perme8_events, :pubsub, Perme8.Events.PubSub)`
  - Keep module name `Perme8.Events.EventBus` unchanged
- [ ] ⏸ **REFACTOR**: Remove `apps/jarga/lib/perme8_events/event_bus.ex` and `apps/jarga/test/perme8_events/event_bus_test.exs`
- [ ] ⏸ **VERIFY**: `mix test apps/perme8_events/test/perme8_events/event_bus_test.exs`

### Step 2.4: Move EventHandler (PubSub-dependent)

- [ ] ⏸ **RED**: Create test `apps/perme8_events/test/perme8_events/event_handler_test.exs`
  - Adapt from `apps/jarga/test/perme8_events/event_handler_test.exs`
  - Change `use Jarga.DataCase, async: false` to `use ExUnit.Case, async: false`
  - Replace all `Phoenix.PubSub.broadcast(Jarga.PubSub, ...)` with `Phoenix.PubSub.broadcast(Perme8.Events.PubSub, ...)`
  - Tests: handler compilation, start/subscription, event routing, error handling, child_spec
- [ ] ⏸ **GREEN**: Move `apps/jarga/lib/perme8_events/event_handler.ex` to `apps/perme8_events/lib/perme8_events/event_handler.ex`
  - In the `__using__` macro's `init/1`, replace `Phoenix.PubSub.subscribe(Jarga.PubSub, topic)` with `Phoenix.PubSub.subscribe(Application.get_env(:perme8_events, :pubsub, Perme8.Events.PubSub), topic)`
  - Keep module name `Perme8.Events.EventHandler` unchanged
- [ ] ⏸ **REFACTOR**: Remove `apps/jarga/lib/perme8_events/event_handler.ex` and `apps/jarga/test/perme8_events/event_handler_test.exs`
- [ ] ⏸ **VERIFY**: `mix test apps/perme8_events/test/perme8_events/event_handler_test.exs`

### Step 2.5: Move Perme8.Events facade (PubSub-dependent)

- [ ] ⏸ **RED**: Create test `apps/perme8_events/test/perme8_events/perme8_events_test.exs`
  - Adapt from `apps/jarga/test/perme8_events/perme8_events_test.exs`
  - Change `use Jarga.DataCase, async: false` to `use ExUnit.Case, async: false`
  - Replace all `Phoenix.PubSub.broadcast(Jarga.PubSub, ...)` with `Phoenix.PubSub.broadcast(Perme8.Events.PubSub, ...)`
  - Tests: subscribe/1 and unsubscribe/1
- [ ] ⏸ **GREEN**: Move `apps/jarga/lib/perme8_events.ex` to `apps/perme8_events/lib/perme8_events.ex`
  - Replace `@pubsub Jarga.PubSub` with `@pubsub Application.compile_env(:perme8_events, :pubsub, Perme8.Events.PubSub)`
  - Update `use Boundary` exports to include `DomainEvent`: `exports: [EventBus, EventHandler, TestEventBus, DomainEvent]`
  - Keep module name `Perme8.Events` unchanged
- [ ] ⏸ **REFACTOR**: Remove `apps/jarga/lib/perme8_events.ex` and `apps/jarga/test/perme8_events/perme8_events_test.exs`
- [ ] ⏸ **VERIFY**: `mix test apps/perme8_events`

### Step 2.6: Remove DomainEvent's standalone boundary (merge into Perme8.Events)

The `DomainEvent` module currently has its own boundary with `check: [in: false]` because it lived in a different app than the rest of `Perme8.Events`. Now that everything is co-located, evaluate:

- [ ] ⏸ **Decision**: Keep `check: [in: false]` on `DomainEvent` so all apps can use `use Perme8.Events.DomainEvent` without declaring a dep on `Perme8.Events`. This is the pragmatic choice — DomainEvent is used by every app's domain layer and should be universally accessible.
- [ ] ⏸ **GREEN**: The `DomainEvent` boundary already has `check: [in: false]`. No change needed to the boundary declaration, but update the `@moduledoc` to reflect new location.

### Phase 2 Validation

- [ ] ⏸ `mix test apps/perme8_events` — ALL 5 test files pass (domain_event, test_event_bus, event_bus, event_handler, perme8_events)
- [ ] ⏸ No leftover `perme8_events*.ex` files in `apps/jarga/lib/` or `apps/identity/lib/`
- [ ] ⏸ `mix compile --warnings-as-errors` — clean compile

---

## Phase 3: Update All Consumers (PubSub rename + dep declarations)

This phase renames `Jarga.PubSub` to `Perme8.Events.PubSub` across all consumer apps and updates their `mix.exs` + boundary configs.

### Step 3.1: Remove PubSub from Jarga.Application

- [ ] ⏸ **RED**: Verify `Jarga.Application` currently starts `{Phoenix.PubSub, name: Jarga.PubSub}` on line 18
- [ ] ⏸ **GREEN**: Remove `{Phoenix.PubSub, name: Jarga.PubSub}` from `apps/jarga/lib/application.ex` children list
  - PubSub is now supervised by `Perme8Events.Application`
- [ ] ⏸ **REFACTOR**: Verify jarga still starts correctly (PubSub comes from perme8_events dep)

### Step 3.2: Update config/config.exs — endpoint pubsub_server references

- [ ] ⏸ Replace all 8 occurrences of `pubsub_server: Jarga.PubSub` with `pubsub_server: Perme8.Events.PubSub` in `config/config.exs`:
  1. `EntityRelationshipManager.Endpoint` (line 47)
  2. `JargaApi.Endpoint` (line 57)
  3. `AgentsApi.Endpoint` (line 67)
  4. `AgentsWeb.Endpoint` (line 77)
  5. `JargaWeb.Endpoint` (line 88)
  6. `IdentityWeb.Endpoint` (line 206)
  7. `ExoDashboardWeb.Endpoint` (line 220)
  8. `Perme8DashboardWeb.Endpoint` (line 234)

### Step 3.3: Update root mix.exs releases

- [ ] ⏸ Add `perme8_events: :permanent` to the release applications list in `mix.exs`:
  ```elixir
  applications: [
    perme8_events: :permanent,  # Must start before apps that need PubSub
    alkali: :permanent,
    identity: :permanent,
    ...
  ]
  ```
  Note: `perme8_events` must be listed first since it supervises the PubSub process that other apps depend on.

### Step 3.4: Update apps that need `{:perme8_events, in_umbrella: true}` dep

Each app that references `Perme8.Events` modules or `Perme8.Events.PubSub` needs the dep and boundary config:

#### identity (already partially done in Phase 1)
- [ ] ⏸ Already has `{:perme8_events, in_umbrella: true}` dep from Step 1.4
- [ ] ⏸ Already has `{:perme8_events, :relaxed}` boundary config from Step 1.4
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in identity

#### jarga (already partially done in Phase 1)
- [ ] ⏸ Already has `{:perme8_events, in_umbrella: true}` dep from Step 1.4
- [ ] ⏸ Already has `{:perme8_events, :relaxed}` boundary config from Step 1.4
- [ ] ⏸ Remove `# Identity (DomainEvent macro lives here for compile-time availability)` comment from jarga's boundary config (no longer relevant)
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in jarga

#### agents
- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/agents/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to agents boundary `check.apps` (if agents has check.apps — currently agents boundary config has no check.apps, so add it)
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in agents

#### entity_relationship_manager
- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/entity_relationship_manager/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to ERM boundary `check.apps`
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in entity_relationship_manager

#### jarga_web
- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/jarga_web/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to jarga_web boundary `check.apps`
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in jarga_web

#### agents_web
- [ ] ⏸ Add `{:perme8_events, in_umbrella: true}` to `apps/agents_web/mix.exs` deps
- [ ] ⏸ Add `{:perme8_events, :relaxed}` to agents_web boundary `check.apps`
- [ ] ⏸ **VERIFY**: `mix compile --warnings-as-errors` in agents_web

#### agents_api (uses identity which uses events, but agents_api itself doesn't directly reference Perme8.Events — check needed)
- [ ] ⏸ Check if agents_api directly references `Perme8.Events` modules. If not, skip. If yes, add dep.

#### jarga_api (same check)
- [ ] ⏸ Check if jarga_api directly references `Perme8.Events` modules. If not, skip. If yes, add dep.

### Step 3.5: Rename Jarga.PubSub in non-event PubSub usage

These are files that use `Jarga.PubSub` for non-event purposes (document CRDT sync, task streaming, etc.). They still need renaming because the PubSub server process name is changing.

#### jarga_web CRDT/document sync
- [ ] ⏸ Update `apps/jarga_web/lib/live/app_live/documents/show.ex`:
  - Replace all 4 occurrences of `Jarga.PubSub` with `Perme8.Events.PubSub`
  - These are direct `Phoenix.PubSub.subscribe/broadcast` calls for document CRDT sync

#### agents SessionsConfig
- [ ] ⏸ Update `apps/agents/lib/agents/sessions/application/sessions_config.ex`:
  - Line 40: Change `config()[:pubsub] || Jarga.PubSub` to `config()[:pubsub] || Perme8.Events.PubSub`

#### Seed files
- [ ] ⏸ Update `apps/jarga/priv/repo/exo_seeds.exs`:
  - Line 26: Change `Phoenix.PubSub.Supervisor.start_link(name: Jarga.PubSub)` to `Phoenix.PubSub.Supervisor.start_link(name: Perme8.Events.PubSub)`
- [ ] ⏸ Update `apps/jarga/priv/repo/exo_seeds_web.exs`:
  - Line 27: Same change as above

### Step 3.6: Rename Jarga.PubSub in test files (non-event tests that stay in their apps)

These test files reference `Jarga.PubSub` directly and are NOT being moved to perme8_events.

#### jarga tests
- [ ] ⏸ Update `apps/jarga/test/projects_test.exs`:
  - Replace 4 occurrences of `Phoenix.PubSub.subscribe(Jarga.PubSub, ...)` with `Phoenix.PubSub.subscribe(Perme8.Events.PubSub, ...)`

#### identity tests
- [ ] ⏸ Update `apps/identity/test/identity/application/use_cases/remove_member_test.exs`:
  - Replace 2 occurrences of `Phoenix.PubSub.subscribe(Jarga.PubSub, ...)` with `Phoenix.PubSub.subscribe(Perme8.Events.PubSub, ...)`

#### agents tests (task_runner tests — 6 files)
- [ ] ⏸ Update the following test files to replace `Jarga.PubSub` with `Perme8.Events.PubSub`:
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/timeout_test.exs` (2 occurrences)
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/sse_crash_test.exs` (2 occurrences)
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/resume_test.exs` (2 occurrences)
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/init_test.exs` (4 occurrences)
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/events_test.exs` (5 occurrences)
  - `apps/agents/test/agents/sessions/infrastructure/task_runner/completion_test.exs` (2 occurrences)

#### jarga_web tests
- [ ] ⏸ Update `apps/jarga_web/test/live/app_live/pages_test.exs`:
  - Replace 3 occurrences of `Jarga.PubSub` with `Perme8.Events.PubSub`

#### perme8_dashboard tests
- [ ] ⏸ Update `apps/perme8_dashboard/test/perme8_dashboard_web/config_test.exs`:
  - Update the test assertion from `Jarga.PubSub` to `Perme8.Events.PubSub` (lines 11, 13)

### Step 3.7: Update event_type_uniqueness_test (stays in jarga)

- [ ] ⏸ Keep `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` in jarga
  - This test references 31 domain event modules across 5 apps — moving it would create circular deps
  - No code changes needed (it uses `ExUnit.Case, async: true` and references module names only)
  - Verify it still passes

### Phase 3 Validation

- [ ] ⏸ `mix compile --warnings-as-errors` — full umbrella compiles cleanly
- [ ] ⏸ `mix boundary` — no boundary violations
- [ ] ⏸ No remaining references to `Jarga.PubSub` in lib/ directories (only in doc strings of Credo checks, which are acceptable)
- [ ] ⏸ `mix test apps/perme8_events` — all perme8_events tests pass
- [ ] ⏸ `mix test apps/jarga/test/perme8_events/` — event_type_uniqueness_test still passes

---

## Phase 4: Update Documentation + Credo Checks + Final Cleanup

### Step 4.1: Update docs/umbrella_apps.md

- [ ] ⏸ Add `perme8_events` to the app table:
  ```
  | `perme8_events` | Elixir (shared infra) | -- | Domain events, PubSub event bus, event handler behaviour |
  ```
- [ ] ⏸ Update the dependency graph to show `perme8_events` at the bottom
- [ ] ⏸ Update the "Shared Event Infrastructure" section:
  - Remove "in `jarga`" and "in `identity`" annotations
  - State all modules live in `perme8_events`
  - Remove the cyclic dependency explanation
- [ ] ⏸ Update the "Rules" section to include `perme8_events` dependency rules

### Step 4.2: Update Credo check doc strings (non-functional)

- [ ] ⏸ Update `.credo/checks/no_pubsub_in_contexts.ex` — change `Jarga.PubSub` in doc string to `Perme8.Events.PubSub` (documentation only, no functional change)
- [ ] ⏸ Update `.credo/checks/no_broadcast_in_transaction.ex` — same doc string update

### Step 4.3: Remove empty perme8_events directories from jarga

- [ ] ⏸ Verify `apps/jarga/lib/perme8_events/` directory is empty and remove it
- [ ] ⏸ Verify `apps/jarga/test/perme8_events/` directory contains only `event_type_uniqueness_test.exs`
- [ ] ⏸ Verify `apps/identity/lib/perme8_events/` directory is empty and remove it

### Step 4.4: Create test_helper.exs for perme8_events

- [ ] ⏸ Create `apps/perme8_events/test/test_helper.exs` with `ExUnit.start()`

### Phase 4 Validation (Pre-commit Checkpoint)

- [ ] ⏸ `mix compile --warnings-as-errors` — no warnings
- [ ] ⏸ `mix format --check-formatted` — all formatted
- [ ] ⏸ `mix credo --strict` — no issues
- [ ] ⏸ `mix boundary` — no violations
- [ ] ⏸ `mix test apps/perme8_events` — all perme8_events tests pass
- [ ] ⏸ `mix test apps/jarga` — jarga tests pass (excluding pre-existing failures)
- [ ] ⏸ `mix test apps/identity` — identity tests pass
- [ ] ⏸ `mix test apps/agents` — agents tests pass (excluding pre-existing failures)
- [ ] ⏸ `mix test apps/entity_relationship_manager` — ERM tests pass
- [ ] ⏸ `mix test apps/jarga_web` — jarga_web tests pass
- [ ] ⏸ `mix test apps/agents_web` — agents_web tests pass (excluding pre-existing failures)
- [ ] ⏸ `mix precommit` — full pre-commit passes (excluding pre-existing failures)

---

## Summary of All File Operations

### New Files Created
| File | Description |
|------|-------------|
| `apps/perme8_events/mix.exs` | Mix project config |
| `apps/perme8_events/lib/perme8_events.ex` | Facade (moved from jarga) |
| `apps/perme8_events/lib/perme8_events/application.ex` | OTP Application with PubSub supervision |
| `apps/perme8_events/lib/perme8_events/domain_event.ex` | DomainEvent macro (moved from identity) |
| `apps/perme8_events/lib/perme8_events/event_bus.ex` | EventBus dispatcher (moved from jarga) |
| `apps/perme8_events/lib/perme8_events/event_handler.ex` | EventHandler behaviour (moved from jarga) |
| `apps/perme8_events/lib/perme8_events/test_event_bus.ex` | Test double (moved from jarga) |
| `apps/perme8_events/test/test_helper.exs` | ExUnit setup |
| `apps/perme8_events/test/perme8_events/application_test.exs` | Application supervision test |
| `apps/perme8_events/test/perme8_events/domain_event_test.exs` | DomainEvent tests (moved) |
| `apps/perme8_events/test/perme8_events/event_bus_test.exs` | EventBus tests (moved + adapted) |
| `apps/perme8_events/test/perme8_events/event_handler_test.exs` | EventHandler tests (moved + adapted) |
| `apps/perme8_events/test/perme8_events/test_event_bus_test.exs` | TestEventBus tests (moved) |
| `apps/perme8_events/test/perme8_events/perme8_events_test.exs` | Facade tests (moved + adapted) |

### Files Deleted (after successful move)
| File | Reason |
|------|--------|
| `apps/jarga/lib/perme8_events.ex` | Moved to perme8_events |
| `apps/jarga/lib/perme8_events/event_bus.ex` | Moved to perme8_events |
| `apps/jarga/lib/perme8_events/event_handler.ex` | Moved to perme8_events |
| `apps/jarga/lib/perme8_events/test_event_bus.ex` | Moved to perme8_events |
| `apps/identity/lib/perme8_events/domain_event.ex` | Moved to perme8_events |
| `apps/jarga/test/perme8_events/domain_event_test.exs` | Moved to perme8_events |
| `apps/jarga/test/perme8_events/event_bus_test.exs` | Moved to perme8_events |
| `apps/jarga/test/perme8_events/event_handler_test.exs` | Moved to perme8_events |
| `apps/jarga/test/perme8_events/test_event_bus_test.exs` | Moved to perme8_events |
| `apps/jarga/test/perme8_events/perme8_events_test.exs` | Moved to perme8_events |

### Files Modified (in place)
| File | Change |
|------|--------|
| `apps/identity/mix.exs` | Add perme8_events dep + boundary |
| `apps/jarga/mix.exs` | Add perme8_events dep + boundary, remove identity comment |
| `apps/agents/mix.exs` | Add perme8_events dep + boundary |
| `apps/entity_relationship_manager/mix.exs` | Add perme8_events dep + boundary |
| `apps/jarga_web/mix.exs` | Add perme8_events dep + boundary |
| `apps/agents_web/mix.exs` | Add perme8_events dep + boundary |
| `apps/jarga/lib/application.ex` | Remove PubSub from children |
| `config/config.exs` | Add perme8_events config; rename 8 pubsub_server references |
| `mix.exs` | Add perme8_events to release applications |
| `apps/agents/lib/agents/sessions/application/sessions_config.ex` | Rename PubSub default |
| `apps/jarga_web/lib/live/app_live/documents/show.ex` | Rename 4 PubSub references |
| `apps/jarga/priv/repo/exo_seeds.exs` | Rename PubSub |
| `apps/jarga/priv/repo/exo_seeds_web.exs` | Rename PubSub |
| `apps/jarga/test/projects_test.exs` | Rename 4 PubSub references |
| `apps/identity/test/identity/application/use_cases/remove_member_test.exs` | Rename 2 PubSub references |
| `apps/agents/test/agents/sessions/infrastructure/task_runner/*.exs` | Rename ~17 PubSub references across 6 files |
| `apps/jarga_web/test/live/app_live/pages_test.exs` | Rename 3 PubSub references |
| `apps/perme8_dashboard/test/perme8_dashboard_web/config_test.exs` | Update assertion |
| `.credo/checks/no_pubsub_in_contexts.ex` | Doc string update |
| `.credo/checks/no_broadcast_in_transaction.ex` | Doc string update |
| `docs/umbrella_apps.md` | Add perme8_events, update graph/docs |

### Files NOT Changed
| File | Reason |
|------|--------|
| `apps/jarga/test/perme8_events/event_type_uniqueness_test.exs` | Stays in jarga (cross-app references) |
| All domain event modules (31 files across 5 apps) | Module names unchanged |
| All use cases referencing `Perme8.Events.EventBus` | Module names unchanged |
| All LiveViews calling `Perme8.Events.subscribe/1` | Module name unchanged |
| `config/dev.exs`, `config/test.exs` | No PubSub references |
| `config/runtime.exs` | No PubSub references |

---

## Testing Strategy

- **Total estimated tests**: ~25 (in perme8_events) + all existing tests pass unchanged
- **Distribution**:
  - perme8_events app: ~25 tests (5 test files, moved + adapted)
  - Modified tests in consumer apps: ~30 files updated (PubSub rename only, no logic changes)
- **Test pyramid**: All perme8_events tests are fast (no database, only PubSub process)
- **Regression**: Full `mix test` must pass with no new failures vs baseline

## Risk Mitigation

1. **Compile order**: perme8_events has no umbrella deps, so it compiles first. All other apps depend on it transitively.
2. **PubSub availability**: `Perme8Events.Application` starts the PubSub process. OTP application boot order ensures it's available before consumers start.
3. **Module resolution**: Module names don't change, so no import/alias changes needed in consumer code. Only `mix.exs` deps matter.
4. **Rollback**: If extraction fails mid-way, all original files still exist until explicitly deleted. Each phase has its own validation gate.
