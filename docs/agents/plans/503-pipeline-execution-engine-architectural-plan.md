# Ticket #503: Pipeline Execution Engine Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/pipeline/`
- Migration path: `apps/agents/priv/repo/migrations/`
- Tests path: `apps/agents/test/agents/pipeline/`

## Scope

Implement the pipeline execution engine that reacts to session and internal-PR events, creates pipeline runs, executes configured stages, tracks lifecycle state, emits stage-change events, and reopens coding sessions when `on_session_complete` stages fail.

## Current Baseline

- Phase 1 already provides parsed pipeline configuration via `Agents.Pipeline.Application.UseCases.LoadPipeline` and value objects such as `PipelineConfig` and `Stage`.
- Phase 2 already provides internal pull-request entities, schemas, repositories, and use cases under `Agents.Pipeline`.
- Session domain events already exist for `TaskCompleted` and `SessionDiffProduced` under `apps/agents/lib/agents/sessions/domain/events/`.
- The pipeline facade currently exposes config loading and internal PR operations only; there is no pipeline-run aggregate, no execution policy, and no event subscriber for orchestration.

## Gaps To Fill

- Persistent storage for pipeline runs is not listed in the ticket but is required for `GetPipelineStatus`, multi-stage tracking, and kanban/session reopening workflows.
- A pipeline stage-change domain event is required for downstream consumers.
- Stage execution should be abstracted behind an injectable behaviour so unit tests can run without containers.
- Event-handler failures must not crash the supervision tree if Repo access or downstream actions fail.

## Proposed Additions

- Domain entities:
  - `Agents.Pipeline.Domain.Entities.PipelineRun`
  - `Agents.Pipeline.Domain.Entities.StageResult`
- Domain policy:
  - `Agents.Pipeline.Domain.Policies.PipelineLifecyclePolicy`
- Domain event:
  - `Agents.Pipeline.Domain.Events.PipelineStageChanged`
- Application use cases:
  - `TriggerPipelineRun`
  - `RunStage`
  - `GetPipelineStatus`
- Application behaviours/runtime dependencies:
  - `PipelineRunRepositoryBehaviour`
  - `StageExecutorBehaviour`
  - runtime config accessors for pipeline-run repo, stage executor, event bus, and session reopen adapter
- Infrastructure:
  - `PipelineRunSchema`
  - `PipelineRunRepository`
  - `PipelineEventHandler`
  - `SessionReopener` adapter or direct facade wrapper around `Agents.Sessions`
- Public facade wiring in `Agents.Pipeline` and `Agents.Pipeline.Application`

## Data Model Recommendation

Add a persisted `pipeline_runs` table in `Agents.Repo`.

Recommended fields:

- `id` (`:binary_id`)
- `trigger_type` (`task_completed`, `session_diff_produced`, `pull_request_updated`, `pull_request_merged`)
- `trigger_reference` (task id, session id, or PR number as string)
- `session_id` (`:binary_id`, nullable)
- `pull_request_number` (`:integer`, nullable)
- `status` (`idle`, `running_stage`, `awaiting_result`, `passed`, `failed`, `deploying`, `reopen_session`)
- `current_stage_id` (`:string`, nullable)
- `remaining_stage_ids` (`{:array, :string}` or embedded JSON list)
- `stage_results` (`:map` / embedded JSON keyed by stage id)
- `failure_reason` (`:string`, nullable)
- `reopened_session_at` (`:utc_datetime`, nullable)
- timestamps

This keeps `StageResult` as a domain value object while allowing schema serialization as maps.

## Execution Model

1. `PipelineEventHandler` subscribes to `TaskCompleted`, `SessionDiffProduced`, and pipeline/PR-related triggers.
2. `TriggerPipelineRun` loads the pipeline config, selects eligible stages for the trigger, creates a persisted `PipelineRun`, and schedules the first stage.
3. `RunStage` transitions the run through `PipelineLifecyclePolicy`, executes the selected stage through an injected `StageExecutorBehaviour`, records a `StageResult`, emits `PipelineStageChanged`, and either:
   - advances to the next stage,
   - transitions to deploy,
   - marks the run failed, or
   - reopens the coding session for `on_session_complete` failures.
4. `GetPipelineStatus` returns the current run plus stage results for kanban/session consumers.

## RED / GREEN / REFACTOR Plan

### Phase 1: Persistence and Domain Event Baseline

- [ ] RED: add migration tests or schema-focused tests proving a pipeline run can persist status, trigger metadata, stage queue, and serialized results
- [ ] GREEN: create `pipeline_runs` migration, `PipelineRunSchema`, and repository scaffolding in `apps/agents/lib/agents/pipeline/infrastructure/`
- [ ] GREEN: add `PipelineRunRepositoryBehaviour` and runtime config wiring in `PipelineRuntimeConfig`
- [ ] GREEN: add `PipelineStageChanged` domain event in `apps/agents/lib/agents/pipeline/domain/events/`
- [ ] REFACTOR: keep schema serialization isolated in repository helpers so domain entities stay persistence-agnostic

### Phase 2: Pipeline Run Aggregate and Lifecycle Policy

- [ ] RED: add unit tests for `PipelineRun` construction, stage enqueue/dequeue behaviour, result recording, failure handling, and event payload generation
- [ ] RED: add exhaustive policy tests for `PipelineLifecyclePolicy` covering `idle -> running_stage -> awaiting_result -> passed|failed -> next action`
- [ ] GREEN: implement `PipelineRun` with explicit fields for trigger context, stage queue, current stage, results, and failure/reopen metadata
- [ ] GREEN: implement `StageResult` as a value object containing stage id, status, output, exit code, timestamps, and optional failure reason
- [ ] GREEN: implement `PipelineLifecyclePolicy` as the single state-transition authority used by use cases
- [ ] REFACTOR: centralize status atoms/strings and transition guards to avoid duplicated branching in use cases and tests

### Phase 3: Triggering Pipeline Runs

- [ ] RED: add tests for `TriggerPipelineRun` selecting `on_session_complete`, `on_pull_request`, and `on_merge` stages from the loaded config
- [ ] RED: add tests for no-op behaviour when a trigger has no matching stages
- [ ] GREEN: implement `TriggerPipelineRun` to:
  - load pipeline config,
  - map incoming domain events to trigger types,
  - persist a `PipelineRun`,
  - emit initial `PipelineStageChanged`, and
  - enqueue or invoke `RunStage` for the first stage
- [ ] GREEN: add facade exports/delegates in `Agents.Pipeline` for triggering and querying runs
- [ ] REFACTOR: isolate trigger-mapping logic in a private mapper module/function so event-handler code stays thin

### Phase 4: Running Stages and Reopening Sessions

- [ ] RED: add tests for `RunStage` success, failure, multi-stage progression, deploy terminal state, and `on_session_complete` reopen behaviour
- [ ] RED: add tests proving `PipelineStageChanged` is emitted on each state transition using `Perme8.Events.TestEventBus`
- [ ] GREEN: add `StageExecutorBehaviour` and a default infrastructure executor that can run pipeline steps against the session container or PR/merge context
- [ ] GREEN: implement `RunStage` to:
  - transition to `running_stage` and `awaiting_result`,
  - execute stage steps,
  - capture output/exit metadata in `StageResult`,
  - persist updated run state,
  - emit `PipelineStageChanged`, and
  - either continue, fail, deploy, or reopen the session
- [ ] GREEN: define a session-reopen path, preferably via a focused adapter that wraps `Agents.Sessions.resume_session/4` or `Agents.Sessions.resume_task/3` depending on how the trigger identifies the coding session
- [ ] REFACTOR: keep container execution concerns outside the use case so stage orchestration remains deterministic in tests

### Phase 5: Event Subscription and Integration Wiring

- [ ] RED: add tests for `PipelineEventHandler` reacting to `TaskCompleted`, `SessionDiffProduced`, internal PR create/update events, and `MergePullRequest` outcomes
- [ ] RED: add defensive tests ensuring handler failures return errors without crashing the GenServer/supervisor
- [ ] GREEN: implement `PipelineEventHandler` with `use Perme8.Events.EventHandler`, subscribe to the relevant topics, map incoming events to `TriggerPipelineRun`, and rescue Repo/runtime failures
- [ ] GREEN: broadcast or publish stage-change events for kanban consumers using the domain event stream rather than direct UI coupling
- [ ] REFACTOR: extract event-to-trigger translation into small functions so adding future trigger types remains safe

### Phase 6: Query API, Facade Completion, and Regression Coverage

- [ ] RED: add tests for `GetPipelineStatus` returning normalized run state and ordered stage results
- [ ] GREEN: implement `GetPipelineStatus` and expose it from the `Agents.Pipeline` facade
- [ ] GREEN: update `Agents.Pipeline.Application` boundary exports for the new repository behaviour, runtime config, and use cases
- [ ] GREEN: add end-to-end-ish integration coverage for the happy path from trigger event -> run creation -> stage result -> emitted event
- [ ] REFACTOR: align naming, docs, and facade surface with existing `Agents.Pipeline` conventions

## Test Strategy

- Unit-test `PipelineLifecyclePolicy` with table-style transition coverage.
- Unit-test `PipelineRun` and `StageResult` as pure domain objects.
- Use fake repositories and fake executors for `TriggerPipelineRun` / `RunStage` use-case tests.
- Inject `Perme8.Events.TestEventBus` into all tests that emit domain events.
- Add repository tests for schema serialization/deserialization of `stage_results` and remaining stage ids.
- Add event-handler tests that exercise subscriptions without relying on real PubSub side effects.
- Add one integration test covering session-triggered test execution and reopen-on-failure semantics.

## Dependency Notes

- Phase 1 (`LoadPipeline`) must expose enough stage metadata to identify trigger type and execution steps.
- Phase 2 internal PR work must provide a reliable event or invocation point for PR creation/update and merge transitions.
- The ticket likely requires one or more new internal pipeline events beyond `PipelineStageChanged` if downstream systems later need run-level summaries; keep that extensible but out of scope unless needed by implementation.

## Risks and Decisions To Resolve Early

- `Reopen the coding session` is ambiguous: confirm whether the source of truth is session id, task id, or both, and whether reopening means `resume_task`, `resume_session`, or creating a fresh task linked to the same session.
- The ticket names `PipelineEventHandler` as subscribing to `TaskCompleted` and `SessionDiffProduced`, but acceptance criteria also require PR creation/update and merge triggers; verify the exact event source for internal PR lifecycle transitions before implementation.
- Running tests inside the session container may require extracting or reusing container/session execution helpers from `Agents.Sessions.Infrastructure.TaskRunner` rather than coupling directly to that GenServer.
- Persisted stage output can become large; consider truncation or summary storage rules if raw command output is substantial.

## Suggested Implementation Order

1. Persistence + domain event baseline
2. Domain aggregate + lifecycle policy
3. Trigger use case
4. Stage execution use case and reopen adapter
5. Event handler integration
6. Query facade and regression coverage
