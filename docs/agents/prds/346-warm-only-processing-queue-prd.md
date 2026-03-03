# PRD: Warm-Only Processing Queue for Agent Sessions (#346)

## Source
- Ticket: #346
- Title: `feat: enforce warm-only processing queue for agent sessions`

## User Story
As a user running queued agent sessions, I want tasks to enter processing only when their containers are warm and ready so starts are reliable and queue order remains predictable.

## App Ownership
- Owning domain app: `agents`
- Owning interface app: `agents_web`
- Owning Repo: `Agents.Repo`

## Scope
- Enforce queue promotion gating in `agents` so cold tasks are not promoted to processing/running.
- Keep warm-pool configuration in `agents_web` Sessions list with a user-configurable count for fresh warm containers.
- Ensure first start of a fresh warm container performs repository updates and token refresh before task execution.

## Scenarios

### Scenario: queued tasks are not promoted when warm readiness is missing
Given a user has queued tasks
And no queued task currently has warm-ready container state
When queue promotion is evaluated
Then no task is promoted into processing/running
And queued order is preserved

### Scenario: warmup flow prepares queued tasks before promotion
Given a user has queued tasks and available capacity
When warmup runs for top queued tasks
Then warmup marks tasks ready only after container preparation succeeds
And only warm-ready tasks can be promoted

### Scenario: session list exposes fresh warm-container target count
Given I am viewing the Sessions list
When I set the fresh warm-container target count
Then the selection is persisted for my session list context
And queue warming behavior uses the configured count

### Scenario: fresh warm container does first-start preparation
Given a task is about to start from a fresh warm container
And the container has never run task execution before
When start begins
Then repository updates run for all configured repos
And auth tokens are refreshed before prompt execution

### Scenario: queue gating and warm-start preparation are covered by automated tests
Given the warm-only promotion and first-start preparation rules
When automated tests run
Then queue gating paths are validated
And warm-start preparation paths are validated

## Constraints
- Preserve ownership boundaries: queue and task lifecycle logic in `agents`; UI controls in `agents_web`.
- Avoid cross-app Repo usage; all persistence remains via `Agents.Repo`.
- Keep queue behavior deterministic under concurrent updates.
