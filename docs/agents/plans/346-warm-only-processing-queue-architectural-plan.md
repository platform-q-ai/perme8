# Feature: Warm-Only Processing Queue for Agent Sessions (#346)

## App Ownership

- Owning domain app: `agents`
- Owning interface app: `agents_web`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/`
- Web path: `apps/agents_web/lib/agents_web/`
- Migration path: `apps/agents/priv/repo/migrations/`

## Implementation Plan

### Phase 1: Queue warm-gating rules
- [x] **RED** Add queue manager tests proving cold queued tasks are not promoted.
- [x] **GREEN** Gate promotion to warm-ready queued tasks only.
- [x] **REFACTOR** Keep warm-target calculation deterministic when capacity opens.

### Phase 2: Fresh warm-container first-start preparation
- [x] **RED** Add task-runner tests for prewarmed container first-start flow.
- [x] **GREEN** Restart prewarmed containers, run fresh-start workspace prep, and refresh auth before session creation.
- [x] **REFACTOR** Keep resume flow unchanged and isolate fresh-start preparation path.

### Phase 3: Session UI control clarity
- [x] **RED/GREEN** Update Sessions queue control language to represent fresh warm-container target.
- [x] **REFACTOR** Preserve existing wire format (`warm_cache_limit`) while clarifying user intent in UI.

### Validation
- [x] Targeted queue manager tests
- [x] Targeted task runner tests
- [x] Targeted sessions LiveView tests
