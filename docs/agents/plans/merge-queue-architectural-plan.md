# Merge Queue Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/`
- Web path: `apps/agents_web/lib/agents_web/`
- Migration path: `apps/agents/priv/repo/migrations/`

## Phases

- [x] RED: add merge queue stage coverage for scheduled entry, batching config, and lifecycle exposure
- [x] GREEN: model merge queue as a normal persisted pipeline stage
- [x] RED: add orchestration tests for queued, merged, and blocked pull requests
- [x] GREEN: keep merge-window batching and merge execution in generic stage/step flow
- [x] RED: add scheduled merge-stage tests for ordering and failure handling
- [x] GREEN: remove dedicated merge queue worker runtime state
- [x] RED: add kanban and pipeline-config tests for merge queue exposure
- [x] GREEN: surface `Merge Queue` in ticket-facing stage catalogs and ticket lifecycle helpers
- [x] REFACTOR: keep merge queue behavior behind the generic `Agents.Pipeline` flow model

## Integration Points

- `PipelineConfig` and the normalized pipeline config loader carry merge queue stage config from the persisted pipeline configuration
- Merge-window batching and merge execution are expressed through normal stage config plus executable steps
- Stage concurrency and lifecycle state own queueing behavior instead of a dedicated in-memory merge queue worker
- `TicketFacingStageCatalog` and ticket lifecycle helpers expose the `merge_queue` stage to the kanban
- `PipelineRunRepository` lists PR-linked verification history for readiness checks
