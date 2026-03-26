# Merge Queue Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/`
- Web path: `apps/agents_web/lib/agents_web/`
- Migration path: `apps/agents/priv/repo/migrations/`

## Phases

- [x] RED: add merge queue policy coverage for readiness, required stages, and review approval
- [x] GREEN: implement `MergeQueuePolicy` and YAML-backed `PipelineConfig.merge_queue`
- [x] RED: add orchestration tests for queued, merged, and blocked pull requests
- [x] GREEN: implement `ManageMergeQueue`, queue state management, and pre-merge validation orchestration
- [x] RED: add merge queue worker tests for ordering and failure handling
- [x] GREEN: implement `MergeQueueWorker` and wire it into the agents supervisor
- [x] RED: add kanban and YAML parser tests for merge queue exposure
- [x] GREEN: surface `Merge Queue` in ticket-facing stage catalogs and ticket lifecycle helpers
- [x] REFACTOR: keep queue integration behind the `Agents.Pipeline` facade and repository behaviours

## Integration Points

- `PipelineConfig` and `YamlParser` carry merge queue policy from the persisted pipeline configuration
- `ManageMergeQueue` composes PR lookup, pipeline run history, queue state, validation reruns, and merge execution
- `MergeQueueWorker` owns in-memory queue ordering and active validation ownership
- `TicketFacingStageCatalog` and ticket lifecycle helpers expose the `merge_queue` stage to the kanban
- `PipelineRunRepository` lists PR-linked verification history for readiness checks
