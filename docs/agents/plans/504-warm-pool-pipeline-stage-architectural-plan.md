# Feature: #504 - Warm Pool Pipeline Stage

## App Ownership

| Artifact | Owning App | Repo | Path |
|----------|-----------|------|------|
| Pipeline domain policy | `agents` | `Agents.Repo` | `apps/agents/lib/agents/pipeline/domain/policies/` |
| Pipeline use cases | `agents` | `Agents.Repo` | `apps/agents/lib/agents/pipeline/application/use_cases/` |
| Pipeline infrastructure | `agents` | `Agents.Repo` | `apps/agents/lib/agents/pipeline/infrastructure/` |
| Sessions queue orchestration | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/infrastructure/` |
| Sessions queue domain policies/entities | `agents` | `Agents.Repo` | `apps/agents/lib/agents/sessions/domain/` |
| OTP supervision wiring | `agents` | `Agents.Repo` | `apps/agents/lib/agents/otp_app.ex` |
| Pipeline config | `agents` | - | `Agents.Repo` persisted document |
| Tests | `agents` | - | `apps/agents/test/agents/` |

## Overview

Ticket #504 moves warm pool provisioning out of `QueueOrchestrator` and into the pipeline subsystem. The persisted pipeline model becomes the source of truth for how warm containers are provisioned, while queue orchestration becomes concurrency-only. The main architectural shift is that "warm pool" stops being a queue lane optimization and becomes a scheduler-driven pipeline stage with explicit policy/config.

This is an internal backend feature. No browser/http/security feature files are required because there is no user-facing adapter surface to express with the available exo-BDD domains.

## Design Decisions

- Introduce a dedicated `WarmPoolPolicy` value/policy layer that interprets warm-pool stage config from persisted pipeline stage records instead of reading queue settings from `SessionsConfig`.
- Extend the pipeline `Stage` entity to preserve stage-specific config so warm-pool metadata survives record loading.
- Keep warm-pool execution on top of the existing generic stage execution path rather than inventing a second executor.
- Add a dedicated `ReplenishWarmPool` use case that decides whether provisioning is needed, then triggers execution of the `warm-pool` stage.
- Add `PipelineScheduler` as a GenServer that periodically calls `ReplenishWarmPool`; wire it into `Agents.OTPApp`.
- Remove warm lane and warm cache metadata from queue snapshots so `QueueOrchestrator` and `QueueEngine` only model processing, queued cold tasks, retry-pending tasks, and awaiting feedback.
- Preserve task/session lifecycle behavior where possible; only remove queue-owned warming logic, not unrelated session/container behavior.

## Config Shape

The warm-pool stage should continue to live in the persisted pipeline configuration, but its stage config needs explicit warm-pool metadata beyond steps:

```yaml
- id: warm-pool
  type: warm_pool
  deploy_target: dev
  schedule:
    cron: "*/5 * * * *"
  warm_pool:
    target_count: 2
    image: ghcr.io/platform-q-ai/perme8-runtime:latest
    readiness:
      strategy: command_success
      required_step: prewarm-session-pool
  steps:
    - name: build-runtime-image
      run: mix release
      timeout_seconds: 900
    - name: prewarm-session-pool
      run: scripts/warm_pool.sh
      timeout_seconds: 600
```

Exact field names can be finalized during implementation, but the plan assumes:

- schedule metadata lives on the stage and includes cron
- warm-pool-specific config lives in a dedicated nested map
- steps remain generic and executable by the existing stage executor

## Phase 1: Pipeline Config + Policy Modeling (phoenix-tdd)

### 1.1 Extend Stage entity to preserve warm-pool config

- [ ] **RED**: Update/add tests:
  - `apps/agents/test/agents/pipeline/domain/entities/stage_test.exs`
  - `apps/agents/test/agents/pipeline/infrastructure/yaml_parser_test.exs`
  - add expectations that a `warm_pool` stage retains `schedule`, `warm_pool`, and any additional config fields after parsing
- [ ] **GREEN**: Update `apps/agents/lib/agents/pipeline/domain/entities/stage.ex`
  - add fields for stage config such as `config` and/or explicit `schedule`
  - keep backward compatibility for existing verification/deploy stages
- [ ] **GREEN**: Update `apps/agents/lib/agents/pipeline/infrastructure/yaml_parser.ex`
  - validate warm-pool stage-specific config
  - preserve nested config on the `Stage` struct instead of dropping it
  - validate that `warm-pool` exists and has the required config keys
- [ ] **REFACTOR**: Extract parser helpers for warm-pool config validation instead of growing `build_stage/3` inline

### 1.2 Implement WarmPoolPolicy

- [ ] **RED**: Add `apps/agents/test/agents/pipeline/domain/policies/warm_pool_policy_test.exs`
  - parse target count, image, readiness criteria, and cron from the stage config
  - reject missing/invalid target count
  - reject missing image/readiness config
  - expose helpers for determining shortage and whether replenishment is required
- [ ] **GREEN**: Create `apps/agents/lib/agents/pipeline/domain/policies/warm_pool_policy.ex`
  - construct a policy from the parsed warm-pool stage
  - expose functions like `from_stage/1`, `target_count/1`, `image/1`, `readiness_criteria/1`, `shortage/2`, `replenishment_required?/2`
- [ ] **REFACTOR**: Keep the policy pure; no repo/process access

### Phase 1 Validation

- [ ] `mix test apps/agents/test/agents/pipeline/domain/entities/stage_test.exs`
- [ ] `mix test apps/agents/test/agents/pipeline/infrastructure/yaml_parser_test.exs`
- [ ] `mix test apps/agents/test/agents/pipeline/domain/policies/warm_pool_policy_test.exs`

---

## Phase 2: Warm Pool Replenishment + Scheduler (phoenix-tdd)

### 2.1 Implement ReplenishWarmPool use case

- [ ] **RED**: Add `apps/agents/test/agents/pipeline/application/use_cases/replenish_warm_pool_test.exs`
  - loads the pipeline, finds the `warm-pool` stage, and builds policy from it
  - compares current warm count against target count
  - does nothing when current warm count meets/exceeds target
  - triggers warm-pool stage execution when below target
  - executes provisioning count based on shortage
  - returns a useful result map/struct for scheduler observability
- [ ] **GREEN**: Create `apps/agents/lib/agents/pipeline/application/use_cases/replenish_warm_pool.ex`
  - load pipeline config
  - resolve warm-pool stage
  - derive policy with `WarmPoolPolicy`
  - consult injected dependency for current warm count
  - trigger generic stage execution for replenishment
  - inject dependencies for parser, runner repo, stage executor, and warm-count provider to keep tests isolated
- [ ] **REFACTOR**: Prefer composition over embedding scheduler logic inside the use case

### 2.2 Scheduler support and trigger integration

- [ ] **RED**: Add `apps/agents/test/agents/pipeline/infrastructure/pipeline_scheduler_test.exs`
  - scheduler reads cron config from the warm-pool stage
  - scheduler invokes `ReplenishWarmPool` on startup/tick
  - scheduler reschedules after each run
  - scheduler handles use case failures without crashing
  - scheduler can be disabled/skipped in tests via injected options or app config
- [ ] **GREEN**: Create `apps/agents/lib/agents/pipeline/infrastructure/pipeline_scheduler.ex`
  - GenServer responsible for computing next tick from cron expression and calling `ReplenishWarmPool`
  - guard against sandbox/repo failures with defensive error handling
  - make the scheduler dependency-injected enough for deterministic unit tests
- [ ] **GREEN**: Wire scheduler into `apps/agents/lib/agents/otp_app.ex`
  - start it under supervision
  - add any runtime config flags needed to suppress the scheduler in test
- [ ] **GREEN**: Update `apps/agents/lib/agents/pipeline/application/use_cases/trigger_pipeline_run.ex` only if needed for consistency
  - do not overload existing session/PR triggers with warm-pool scheduling unless it simplifies the design cleanly
  - if direct trigger support is added, ensure `warm_pool` stages are explicitly selected only for the scheduler/warm-pool trigger
- [ ] **REFACTOR**: Export/inject scheduler dependencies via pipeline runtime config if that keeps wiring consistent with existing pipeline use cases

### Phase 2 Validation

- [ ] `mix test apps/agents/test/agents/pipeline/application/use_cases/replenish_warm_pool_test.exs`
- [ ] `mix test apps/agents/test/agents/pipeline/infrastructure/pipeline_scheduler_test.exs`
- [ ] targeted regression tests for `trigger_pipeline_run`

---

## Phase 3: Remove Warm Pool Ownership From Queueing (phoenix-tdd)

### 3.1 Simplify QueueOrchestrator to concurrency-only behavior

- [ ] **RED**: Update `apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
  - remove/rewrite warming-specific describes
  - assert queue promotion still works with queued tasks but no warm scheduling side effects
  - assert there is no `set_warm_cache_limit/2` or `get_warm_cache_limit/1` public behavior remaining through sessions facade/orchestrator behavior tests
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/infrastructure/queue_orchestrator.ex`
  - remove warm state from GenServer state (`warm_cache_limit`, `warmup_scheduled`, `warming_task_ids`, `container_provider` if only used for warming)
  - remove warm-pool handle_info callbacks and helper functions
  - remove warm-cache API functions
  - keep only promotion, retry, and concurrency responsibilities
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions.ex`
  - remove public warm-cache facade functions if still present
- [ ] **GREEN**: Update any queue-orchestrator behaviour modules/config that still mention warm-cache operations
- [ ] **REFACTOR**: remove dead code and unused aliases/imports once warm paths are gone

### 3.2 Remove warm lane modeling from queue domain

- [ ] **RED**: Update/add tests:
  - `apps/agents/test/agents/sessions/domain/policies/queue_engine_test.exs`
  - `apps/agents/test/agents/sessions/domain/entities/queue_snapshot_test.exs`
  - any session/dashboard helpers that still expect warm lane metadata
  - assert queued tasks are modeled without warm lane separation
- [ ] **GREEN**: Update `apps/agents/lib/agents/sessions/domain/policies/queue_engine.ex`
  - remove `:warm` lane and warm/cold split
  - simplify queued lane assignment so non-retry queued tasks are just queueable work
  - update promotion helpers accordingly
- [ ] **GREEN**: Update queue snapshot/domain entities and legacy map conversion so warm metadata is removed
- [ ] **GREEN**: Update any callers/tests in dashboard helpers or support modules that still derive sticky warm IDs from queue state
- [ ] **REFACTOR**: normalize naming so queue data reflects the new concurrency-only model

### Phase 3 Validation

- [ ] `mix test apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
- [ ] `mix test apps/agents/test/agents/sessions/domain/policies/queue_engine_test.exs`
- [ ] `mix test apps/agents/test/agents/sessions/domain/entities/queue_snapshot_test.exs`

---

## Phase 4: End-to-End Pipeline/Queue Integration Regression Pass (phoenix-tdd)

### 4.1 Verify warm-pool stage runs declaratively from YAML

- [ ] **RED**: Add/extend integration-focused tests:
  - `apps/agents/test/agents/pipeline/application/use_cases/load_pipeline_test.exs`
  - `apps/agents/test/agents/pipeline/application/use_cases/pipeline_run_workflows_test.exs`
  - optionally `apps/agents/test/agents/pipeline/infrastructure/pipeline_event_handler_test.exs` if scheduler/run creation shares runtime behavior with existing triggers
  - ensure adding/changing warm-pool steps in YAML changes executed commands without code changes
- [ ] **GREEN**: Ensure the scheduler/use case/executor path reads the persisted pipeline configuration and executes the stage steps exactly as configured
- [ ] **GREEN**: Ensure warm count, target count, image, and readiness criteria are all driven from YAML-derived stage config
- [ ] **REFACTOR**: tighten logging and returned metadata so operations can observe why a replenish run was skipped or executed

### 4.2 Final cleanup

- [ ] remove stale session warming docs/comments that imply queue-owned warm pool behavior
- [ ] update plan/ticket references in code comments only where necessary

### Phase 4 Validation

- [ ] `mix test apps/agents/test/agents/pipeline/application/use_cases/load_pipeline_test.exs`
- [ ] `mix test apps/agents/test/agents/pipeline/application/use_cases/pipeline_run_workflows_test.exs`
- [ ] `mix test apps/agents/test/agents/pipeline/infrastructure/pipeline_event_handler_test.exs` (if affected)
- [ ] `mix test apps/agents/test/agents/sessions/infrastructure/queue_orchestrator_test.exs`
- [ ] `mix boundary`

## Implementation Notes

- Use `TestEventBus` in tests that exercise use cases emitting domain events, per `AGENTS.md` guidance.
- Prefer injected collaborators for warm-count lookup and stage execution so replenishment tests stay unit-level rather than full integration.
- Be careful updating queue snapshots because `agents_web` dashboard helpers currently read warm metadata; either remove those expectations or adjust them to the new queue model in the same phase.
- Avoid changing unrelated task lifecycle semantics unless tests prove they are tightly coupled to removed warm-pool behavior.

## Suggested Commit Points

1. `feat(agents): model warm pool pipeline policy from yaml`
2. `feat(agents): add scheduler-driven warm pool replenishment`
3. `refactor(agents): remove warm pool logic from queue orchestration`
4. `test(agents): cover warm pool scheduling and queue regressions`
