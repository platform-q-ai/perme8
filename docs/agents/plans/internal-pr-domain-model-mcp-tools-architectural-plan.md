# Internal PR Domain Model + MCP Tools Architectural Plan

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/`
- Migration path: `apps/agents/priv/repo/migrations/`
- Feature files: `apps/agents/test/features/perme8-mcp/pr-tools/`

## Ticket

- Ticket: `#502`
- Draft PR: `#518`
- Branch: `feat/502-internal-pr-domain-model-mcp-tools`

## Goals

- Add internal pull request artifacts stored in `Agents.Repo`
- Support PR comments, reviews, diffs, merge, and close operations through MCP tools
- Keep PRs local pipeline artifacts rather than GitHub PRs
- Cover the new behavior with unit tests and MCP tool tests

## Risks And Assumptions

- Current repo guidance still treats GitHub PRs as `gh`-managed external artifacts, so docs may need follow-up updates once the internal PR workflow ships.
- `pr.merge` must mutate git state from the container/session environment; implementation should isolate shell execution behind infrastructure to keep use cases testable.
- Existing MCP tool/provider patterns under tickets should be mirrored to reduce surface-area risk.
- Branch and ticket linkage may need to remain lightweight in phase 1 of implementation if no existing PR schema relationship pattern exists.

## Phases

### Phase 1: Domain Model And Persistence Foundations ✓

- [x] RED: add failing tests for PR entities, repository behavior, and persistence schemas
- [x] GREEN: implement `PullRequest`, `Review`, and `ReviewComment` entities with supported states `draft`, `open`, `in_review`, `approved`, `merged`, `closed`
- [x] GREEN: add Ecto schemas and repository implementation for PRs, comments, and reviews in `agents`
- [x] GREEN: add migrations for `pull_requests`, `pr_comments`, and `pr_reviews`
- [x] REFACTOR: align naming, status transitions, and timestamps with existing ticket repository patterns

### Phase 2: Application Use Cases And Git Diff Infrastructure ✓

- [x] RED: add failing tests for create, read/list support, update, comment, review, diff, merge, and close workflows
- [x] GREEN: implement PR use cases under `apps/agents/lib/agents/pipeline/application/use_cases/`
- [x] GREEN: implement `GitDiffComputer` infrastructure for branch diff computation
- [x] GREEN: implement merge behavior through infrastructure abstraction so merge logic remains unit-testable
- [x] REFACTOR: extract shared validation/state-transition helpers where duplication appears

### Phase 3: MCP Tool Surface ✓

- [x] RED: add failing tests for `pr.create`, `pr.read`, `pr.update`, `pr.list`, `pr.diff`, `pr.comment`, `pr.review`, `pr.merge`, and `pr.close`
- [x] GREEN: implement MCP tool modules and provider registration using existing ticket tool patterns
- [x] GREEN: ensure tool permission names align with `mcp:pr.*`
- [x] GREEN: format MCP responses consistently with current ticket MCP tools
- [x] REFACTOR: share formatting/helpers where appropriate without coupling tickets and PRs too tightly

### Phase 4: Verification And Hardening ✓

- [x] RED/GREEN: add coverage for validation errors, not-found cases, and merge/diff failure paths
- [x] GREEN: verify exo-bdd config and PR MCP feature files still align with implementation
- [x] GREEN: run targeted agents tests, then broader precommit checks
- [x] REFACTOR: clean up docs/config impacted by the new internal PR workflow

## Test Strategy

- Entity and repository unit tests in `apps/agents/test/agents/pipeline/...`
- Use case tests with infrastructure doubles/mocks for git operations
- MCP tool tests mirroring ticket tool tests and permission behavior
- Keep exo-bdd HTTP/security feature files as acceptance guardrails for the MCP surface

## Deliverables

- Internal PR domain entities
- Agents.Repo-backed PR persistence
- PR use cases including diff/merge/close/review/comment flows
- MCP PR tool provider and tool modules
- Migration files for PR persistence tables
- Unit and MCP tests covering happy-path and failure-path behavior
