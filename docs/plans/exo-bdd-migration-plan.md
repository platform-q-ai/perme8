# Migration Plan: Elixir Cucumber → Exo-BDD

## Overview

Two apps use the legacy Elixir Cucumber (`{:cucumber, "~> 0.4.2"}`) with app-specific step definitions: **jarga_web** (24 features, ~65 step files) and **alkali** (8 features, ~8 step files). The goal is to migrate all 32 features into exo-bdd format and remove the Elixir cucumber infrastructure entirely.

---

## Phase 0: Preparation

### 0.1 — Seed data for jarga_web
The existing jarga_api exo-bdd config already starts `mix phx.server` on port 4005 and seeds via `apps/jarga/priv/repo/exo_seeds.exs`. The jarga_web features need the same seed data (users, workspaces, projects, documents, agents, chat sessions). Either:
- **Extend** the existing `exo_seeds.exs` to cover the jarga_web test scenarios, OR
- Create a dedicated `exo_seeds_web.exs` that adds the additional fixtures (user roles, pre-populated chat histories, etc.)

### 0.2 — Seed data for alkali
Alkali is a CLI tool (static site generator), not a web app. Its features test mix tasks (`mix alkali.new`, `mix alkali.build`). These map to the **CLI adapter**. No seed data needed — the CLI steps create temp directories and files as part of each scenario's `Given` steps.

### 0.3 — Determine adapter mapping for each feature group

| App | Feature Domain | Target Adapter(s) | Rationale |
|-----|---------------|-------------------|-----------|
| jarga_web | workspaces/crud, members, navigation | **browser** | UI interaction, form filling, navigation |
| jarga_web | projects/crud, access, integration | **browser** | UI interaction, authorization checks |
| jarga_web | documents/crud, listing, access, components, collaboration, editor | **browser** | LiveView UI, editor interactions |
| jarga_web | chat/messaging, streaming, sessions, panel, editor, context, agents | **browser** | LiveView real-time UI, WebSocket streaming |
| jarga_web | agents/crud, discovery, realtime, workspaces | **browser** | UI management of agents |
| alkali | scaffold_site, build_site, create_post | **cli** | `mix alkali.new`, `mix alkali.build` |
| alkali | layout_system, frontmatter_validation, slug_generation | **cli** | `mix alkali.build` with assertions on output |
| alkali | clean_output, asset_processing | **cli** | `mix alkali.clean`, build output assertions |

### 0.4 — Audit step coverage gaps
Review the exo-bdd built-in steps to identify any scenarios that **cannot** be expressed with existing steps. Key concerns:
- **Data tables in `Given` steps** (e.g., `I fill in the workspace form with: | Field | Value |`) — the browser adapter has `When I fill {string} with {string}` but not data-table-driven form fills. May need multiple `fill` steps per field.
- **LiveView-specific assertions** (e.g., `user messages should be right-aligned`, `code block should have syntax highlighting classes`) — these require CSS selector assertions. The browser adapter has `Then I should see {string}` and element visibility checks, but may need `Then the element {string} should be visible` or attribute assertions.
- **Database assertions** (e.g., `the message should be persisted to the database`) — exo-bdd is black-box only. These must be replaced with observable behavior (API call to verify, or UI reload to confirm persistence).
- **Streaming/real-time assertions** (e.g., `When the agent responds with...`, streaming scenarios) — browser adapter can wait for elements to appear, but explicit streaming checks may need careful `Then I should see {string}` with adequate timeouts.

---

## Phase 1: Alkali (CLI Adapter) — 8 features

Alkali is the simpler migration because it maps cleanly to the CLI adapter.

### 1.1 — Create exo-bdd config
Create `apps/alkali/test/exo-bdd-alkali.config.ts`:
```ts
import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.cli.feature'],
  adapters: {
    cli: {
      workingDir: '/tmp/alkali-test',
      env: { MIX_ENV: 'test' },
    },
  },
})
```

### 1.2 — Translate each feature file
For each of the 8 alkali features, create a `.cli.feature` equivalent:

| Source | Target |
|--------|--------|
| `alkali/build_site.feature` | `build_site.cli.feature` |
| `alkali/scaffold_site.feature` | `scaffold_site.cli.feature` |
| `alkali/create_post.feature` | `create_post.cli.feature` |
| `alkali/layout_system.feature` | `layout_system.cli.feature` |
| `alkali/frontmatter_validation.feature` | `frontmatter_validation.cli.feature` |
| `alkali/slug_generation.feature` | `slug_generation.cli.feature` |
| `alkali/clean_output.feature` | `clean_output.cli.feature` |
| `alkali/asset_processing.feature` | `asset_processing.cli.feature` |

Translation approach — use the **exo-bdd-cli** subagent for each file. Example mapping:
- `Given a static site exists with config:` → `Given I set env "ALKALI_TITLE" to "My Blog"` + setup commands
- `When I run "mix alkali.build"` → `When I run "mix alkali.build"`
- `Then the build should succeed` → `Then the exit code should be 0`
- `And the output directory should contain:` → `Then stdout should contain "first-post.html"` or use file-check commands

### 1.3 — Verify alkali exo-bdd features pass
```bash
mix exo_test --app alkali
```

### 1.4 — Remove legacy alkali cucumber infrastructure
- Delete `apps/alkali/test/features/step_definitions/` (8 files)
- Delete `apps/alkali/test/features/alkali/` (old `.feature` files)
- Remove `{:cucumber, "~> 0.4.2", only: :test}` from `apps/alkali/mix.exs`
- Remove `{:floki, "~> 0.36.0", only: :test}` if only used by cucumber steps
- Remove `test_pattern: "*_test.exs"` comment about cucumber from `mix.exs`

---

## Phase 2: Jarga Web (Browser Adapter) — 24 features

### 2.1 — Create exo-bdd config
Create `apps/jarga_web/test/exo-bdd-jarga-web.config.ts`:
```ts
import { defineConfig } from '../../../tools/exo-bdd/src/index.ts'

export default defineConfig({
  features: ['./features/**/*.browser.feature'],
  servers: [
    {
      name: 'jarga-web',
      command: 'mix phx.server',
      port: 4002,
      workingDir: '../../../',
      env: { MIX_ENV: 'test' },
      seed: 'mix run --no-start apps/jarga/priv/repo/exo_seeds_web.exs',
      healthCheckPath: '/',
      startTimeout: 30000,
    },
  ],
  timeout: 120_000,
  variables: {
    ownerEmail: 'alice@example.com',
    ownerPassword: 'test-password-123',
    adminEmail: 'bob@example.com',
    // ... other test users
  },
  adapters: {
    browser: {
      baseURL: 'http://localhost:4002',
      headless: true,
    },
  },
})
```

### 2.2 — Extend seed data
Update or create `apps/jarga/priv/repo/exo_seeds_web.exs` to provision:
- Test users (alice, bob, charlie, diana, eve) with known passwords
- Workspaces with memberships at each role level
- Projects, documents, agents with known IDs for deterministic testing
- Chat sessions with message history for history-related scenarios

### 2.3 — Translate features by domain (5 groups)

Use the **exo-bdd-browser** subagent for each translation. Order by complexity (simplest first):

#### Group A: Workspaces (3 features)
| Source | Target |
|--------|--------|
| `workspaces/crud.feature` | `workspaces/crud.browser.feature` |
| `workspaces/members.feature` | `workspaces/members.browser.feature` |
| `workspaces/navigation.feature` | `workspaces/navigation.browser.feature` |

Key translation patterns:
- `Given I am logged in as "alice@example.com"` → `Given I navigate to "/users/log-in"` + `When I fill "Email" with "alice@example.com"` + `When I fill "Password" with "${ownerPassword}"` + `When I click the "Log in" button` (or extract into a Background with login macro)
- `When I click "New Workspace"` → `When I click the "New Workspace" button` or `When I click the "New Workspace" link`
- Data table form fills → individual `When I fill {string} with {string}` steps
- `Then I should see "Workspace created"` → `Then I should see "Workspace created"`

#### Group B: Projects (3 features)
| Source | Target |
|--------|--------|
| `projects/crud.feature` | `projects/crud.browser.feature` |
| `projects/access.feature` | `projects/access.browser.feature` |
| `projects/integration.feature` | `projects/integration.browser.feature` |

#### Group C: Documents (6 features)
| Source | Target |
|--------|--------|
| `documents/crud.feature` | `documents/crud.browser.feature` |
| `documents/listing.feature` | `documents/listing.browser.feature` |
| `documents/access.feature` | `documents/access.browser.feature` |
| `documents/components.feature` | `documents/components.browser.feature` |
| `documents/collaboration.feature` | `documents/collaboration.browser.feature` |
| `documents/editor_checkbox_strikethrough.feature` | `documents/editor.browser.feature` |

#### Group D: Chat (7 features) — most complex
| Source | Target |
|--------|--------|
| `chat/messaging.feature` | `chat/messaging.browser.feature` |
| `chat/streaming.feature` | `chat/streaming.browser.feature` |
| `chat/sessions.feature` | `chat/sessions.browser.feature` |
| `chat/panel.feature` | `chat/panel.browser.feature` |
| `chat/editor.feature` | `chat/editor.browser.feature` |
| `chat/context.feature` | `chat/context.browser.feature` |
| `chat/agents.feature` | `chat/agents.browser.feature` |

Special considerations:
- Database assertions (e.g., `message should be persisted`) → replace with reload-and-verify or API call
- Streaming assertions → `Then I should see {string}` with implicit Playwright auto-wait
- Keyboard interactions (`Shift+Enter`) → `When I type {string}` or Playwright keyboard steps if available
- Markdown rendering assertions → CSS selector-based: `Then the element "pre code" should be visible`

#### Group E: Agents (4 features)
| Source | Target |
|--------|--------|
| `agents/crud.feature` | `agents/crud.browser.feature` |
| `agents/discovery.feature` | `agents/discovery.browser.feature` |
| `agents/realtime.feature` | `agents/realtime.browser.feature` |
| `agents/workspaces.feature` | `agents/workspaces.browser.feature` |

### 2.4 — Verify jarga_web exo-bdd features pass
```bash
mix exo_test --app jarga_web
```
Run group by group, fixing issues before proceeding to the next.

### 2.5 — Remove legacy jarga_web cucumber infrastructure
- Delete `apps/jarga_web/test/features/step_definitions/` (entire directory, ~65 files)
- Delete `apps/jarga_web/test/features/support/` (hooks.exs, wallaby_support.exs)
- Delete old `.feature` files from each subdirectory (the ones without `.browser.` suffix)
- Remove from `apps/jarga_web/mix.exs`:
  - `{:cucumber, "~> 0.4.2", only: :test}`
  - `{:wallaby, "~> 0.30", runtime: false, only: :test}`
  - `{:lazy_html, ">= 0.1.0", only: :test}` (if only used by cucumber)
- Remove the `test_pattern` comment about cucumber

---

## Phase 3: Cleanup & Documentation

### 3.1 — Update FEATURE_TESTING_GUIDE.md
`docs/prompts/architect/FEATURE_TESTING_GUIDE.md` is 924 lines focused entirely on Elixir Cucumber. Either:
- **Rewrite** to reference exo-bdd exclusively, or
- **Replace** with a pointer to `tools/exo-bdd/EXO-BDD-SPEC.md` and `tools/exo-bdd/README.md`

### 3.2 — Remove cucumber from lockfile
```bash
mix deps.unlock cucumber wallaby lazy_html
mix deps.clean cucumber wallaby lazy_html --unused
```

### 3.3 — Verify no remaining cucumber references
```bash
grep -r "cucumber" apps/ --include="*.ex" --include="*.exs" --include="*.feature"
grep -r "Cucumber" apps/ --include="*.ex" --include="*.exs"
grep -r "wallaby" apps/ --include="*.ex" --include="*.exs"
```

### 3.4 — Run full exo-bdd test suite
```bash
mix exo_test
```
Confirm all apps (entity_relationship_manager, jarga_api, identity, jarga_web, alkali) pass.

---

## Execution Order & Estimated Effort

| Phase | Scope | Feature Count | Estimated Effort | Risk |
|-------|-------|---------------|-----------------|------|
| 0 | Preparation (audit, seed data) | — | Medium | Low |
| 1 | Alkali CLI migration | 8 | Low-Medium | Low (clean CLI mapping) |
| 2A | Workspaces browser migration | 3 | Medium | Medium |
| 2B | Projects browser migration | 3 | Medium | Medium |
| 2C | Documents browser migration | 6 | Medium-High | Medium (editor complexity) |
| 2D | Chat browser migration | 7 | High | High (streaming, real-time, keyboard) |
| 2E | Agents browser migration | 4 | Medium | Medium |
| 3 | Cleanup & docs | — | Low | Low |

**Recommended approach**: Execute phases sequentially with a commit at each sub-phase boundary. Start with Phase 1 (alkali) as a warm-up since CLI mapping is the most straightforward, then proceed through Phase 2 groups A→E in order of increasing complexity. This lets you build confidence and discover any browser adapter gaps early in the simpler workspace/project features before tackling chat.

**Key risk**: The chat features (Phase 2D) rely heavily on LiveView-specific behaviors (streaming, PubSub, keyboard shortcuts) that may push the boundaries of what the browser adapter can express declaratively. Some scenarios may need to be simplified or split into separate concerns (UI rendering vs. data persistence vs. real-time behavior).
