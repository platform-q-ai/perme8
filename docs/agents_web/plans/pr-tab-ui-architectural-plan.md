# Feature: #506 - PR Tab UI

## App Ownership

- Owning app: `agents`
- Owning Repo: `Agents.Repo`
- Domain path: `apps/agents/lib/agents/`
- Web path: `apps/agents_web/lib/agents_web/`
- API path: `apps/agents_api/lib/agents_api/`
- Migration path: `apps/agents/priv/repo/migrations/`

## Overview

Add a `pr` tab to the sessions dashboard so users can review internal pull requests entirely inside Perme8. The tab must be conditional on the selected ticket having a linked internal PR, lazy-load its data from the local DB, render a local diff, support review comments and review submission, and keep pipeline status out of the panel.

## Constraints

- No GitHub API calls for PR data
- Keep pipeline status out of the PR panel
- Stay within `agents` for PR domain persistence and `agents_web` for LiveView/UI
- Use `Agents.Pipeline.Infrastructure.GitDiffComputer` for local diff generation
- Preserve existing session tab URL semantics with `?tab=pr`

## Gaps Found

- Existing internal PR persistence supports PRs, flat comments, and review decisions, but not reply threading or resolved-thread state.
- Existing PR records do not persist a dedicated PR author field.
- The dashboard currently has no helper for resolving a PR from the selected ticket.

---

## Phase 1: Extend PR Domain for UI Requirements ✓

Goal: add the minimum domain persistence and use cases needed for replies, thread resolution, and ticket-linked PR lookup.

### 1.1 - RED

- [x] Add failing domain/repository/use-case tests for:
  - lookup by `linked_ticket`
  - replying to an existing PR comment thread
  - resolving a comment thread
  - preserving flat comment behavior for existing callers

### 1.2 - GREEN

- [x] Add migration(s) in `apps/agents/priv/repo/migrations/` to support:
  - `parent_comment_id`
  - `resolved`
  - `resolved_at`
  - `resolved_by`
- [x] Update comment schema/entity/repository behavior to persist thread metadata
- [x] Add/extend use cases for:
  - get PR by linked ticket
  - comment reply
  - resolve thread
- [x] Expose new operations through `Agents.Pipeline`

### 1.3 - REFACTOR

- [x] Keep legacy comment creation path backward-compatible
- [x] Normalize thread grouping in one place so the UI does not duplicate thread logic

### Phase 1 Validation

- [x] `mix test apps/agents/test/agents/pipeline/`
- [x] No boundary violations

---

## Phase 2: Add Dashboard PR Data Loading and Tab Resolution ✓

Goal: make the dashboard aware of linked PRs and accept `?tab=pr` only when relevant.

### 2.1 - RED

- [x] Add failing LiveView/helper tests covering:
  - `session_tabs/0` includes `pr` when a linked PR exists
  - `resolve_active_tab/2` accepts `pr`
  - `switch_tab` preserves `tab=pr`
  - selected sessions without a linked PR do not show the PR tab

### 2.2 - GREEN

- [x] Update `apps/agents_web/lib/live/dashboard/helpers/task_execution_helpers.ex`
- [x] Update `apps/agents_web/lib/live/dashboard/session_handlers.ex`
- [x] Load linked PR data lazily in `apps/agents_web/lib/live/dashboard/index.ex`
- [x] Add assigns for:
  - selected PR
  - PR diff payload
  - grouped review threads
  - PR loading/error state

### 2.3 - REFACTOR

- [x] Move PR loading/grouping logic into a dedicated helper module if `index.ex` gets noisy
- [x] Keep `detail_tabs` assembly in one place so chat/ticket/pr rules stay consistent

### Phase 2 Validation

- [x] LiveView tab tests pass
- [x] Direct navigation to `?tab=pr` works only when a linked PR exists

---

## Phase 3: Build Read-Only PR Panel ✓

Goal: render header, description, diff, and thread history with no mutation yet.

### 3.1 - RED

- [x] Add failing component/LiveView tests for:
  - PR header content
  - markdown description rendering
  - file-by-file diff rendering
  - thread rendering grouped by file/line
  - absence of pipeline status widgets

### 3.2 - GREEN

- [x] Create `apps/agents_web/lib/live/dashboard/components/pr_components.ex`
- [x] Add `pr_tab_panel/1` to `apps/agents_web/lib/live/dashboard/components/detail_panel_components.ex`
- [x] Render:
  - title, status, branches, timestamps
  - markdown body
  - file-by-file diff sections with code blocks / syntax classes
  - grouped comment threads and existing reviews
- [x] Update `apps/agents_web/lib/live/dashboard/index.html.heex` to show the panel

### 3.3 - REFACTOR

- [x] Extract diff parsing/presentation helpers out of the component body
- [x] Keep selector/data-testid naming aligned with `pr-tab.browser.feature`

### Phase 3 Validation

- [x] Read-only PR scenarios pass in LiveView tests
- [x] Browser feature selectors exist for header/diff/thread content

---

## Phase 4: Add PR Interaction Handlers ✓

Goal: support inline comments, replies, resolve, and review submission from the PR tab.

### 4.1 - RED

- [x] Add failing tests for:
  - adding a new inline comment
  - replying to an existing thread
  - resolving a thread
  - submitting approve/request-changes/comment reviews

### 4.2 - GREEN

- [x] Create `apps/agents_web/lib/live/dashboard/pr_handlers.ex`
- [x] Delegate PR events from `apps/agents_web/lib/live/dashboard/index.ex`
- [x] Wire handlers to new `Agents.Pipeline` use cases
- [x] Refresh PR assigns after each successful mutation

### 4.3 - REFACTOR

- [x] Centralize PR reload after mutation
- [x] Normalize optimistic/error handling for PR actions

### Phase 4 Validation

- [x] Interaction tests pass
- [x] Review actions update UI state from local DB only

---

## Phase 5: Browser Coverage and Final Hardening ⏳

Goal: align the implementation with the browser feature spec and catch regressions.

### 5.1 - RED

- [x] Run the PR tab browser feature and capture failing steps

### 5.2 - GREEN

- [x] Add/adjust fixtures and test IDs needed for browser scenarios
- [ ] Make `apps/agents_web/test/features/dashboard/pr-tab.browser.feature` pass

### 5.3 - REFACTOR

- [x] Remove duplicate setup and tighten helper naming
- [x] Verify the existing `apps/agents_web/test/exo-bdd-agents-web.config.ts` remains the only config in use

### Phase 5 Validation

- [x] Relevant `agents` and `agents_web` tests pass
- [ ] Browser feature passes
- [x] `mix format --check-formatted`

## Implementation Order

1. Domain support for ticket lookup, replies, and resolve
2. Dashboard tab resolution and lazy PR loading
3. Read-only PR panel rendering
4. PR mutation handlers and UI wiring
5. Browser fixture/test alignment and cleanup

## Key Risks

- Reply/resolve behavior is not just UI work; it requires domain persistence changes in `agents`
- Diff rendering may need a lightweight parser/presenter because the existing API returns raw unified diff text
- The acceptance criteria mention PR author, but current persistence does not store a dedicated PR author field; if required by tests, that will need a small schema extension or a documented fallback
