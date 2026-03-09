# AGENTS.md

## GitHub Identity & Authentication

Perme8 uses two GitHub App identities:

- `perme8[bot]` for commits, PR creation/updates, issues, and PR comment-addressing replies.
- `platformqbot[bot]` for automated PR reviews that may submit `REQUEST_CHANGES`.

### Git Commits

Local git config is set to the bot identity — no extra steps needed:
- `user.name`: `perme8[bot]`
- `user.email`: `262472400+perme8[bot]@users.noreply.github.com`

### GitHub API / `gh` CLI Operations

Use the right token for the operation:

- `perme8[bot]` operations (default for most workflows):

```bash
export GH_TOKEN=$(~/.config/perme8/get-token)
```

- `platformqbot[bot]` automated PR review operations:

```bash
export GH_TOKEN=$(~/.config/perme8/get-review-token)
```

The token is short-lived (9 minutes). Re-generate if a command fails with a 401.

Automated review workflows must skip events where the sender/reviewer identity is `platformqbot` to avoid review loops.

Review-bot token generation requires:
- `GITHUB_REVIEW_APP_ID` (reviewer app id)
- `GITHUB_REVIEW_APP_PEM` (base64-encoded reviewer app private key)
- optional `GITHUB_REVIEW_APP_OWNER` (defaults to `platform-q-ai`)

### Pushing Code

The remote uses SSH which authenticates as `@krisquigley`. To push as the bot, use HTTPS with the token:

```bash
TOKEN=$(~/.config/perme8/get-token)
git push "https://x-access-token:${TOKEN}@github.com/platform-q-ai/perme8.git" <branch>
```

### Manual Use (`@krisquigley`)

- `gh` CLI without `GH_TOKEN` defaults to `@krisquigley` (PAT in keyring)
- `git push` via SSH defaults to `@krisquigley`
- For manual commits: `git -c user.name='Kris Quigley' -c user.email='5502215+krisquigley@users.noreply.github.com' commit`

## App Ownership & Architectural Rules

For the full ownership registry, file placement tables, and domain event rules, see [`docs/app_ownership.md`](docs/app_ownership.md). That document is the authoritative reference -- if it conflicts with other docs, it wins.

Code-generating skills (CRUD Create, CRUD Update, CRUD Delete, Generate Exo-BDD Features) and documentation skills (Check Documentation) consult `docs/app_ownership.md` at invocation time to determine file placement, Repo usage, and boundary validation. See the Skill Enforcement table in that document for details.

### Standalone App Principle

> Every domain app must boot and function without other domain apps (except `identity` for auth and `perme8_events` for event infrastructure). No shared Repos. No cross-app schema references. Communicate via domain events or public facade APIs.

### Decision Tree

When adding a new feature or placing code:

1. **Determine the owning app** -- which app in the [ownership registry](docs/app_ownership.md) owns the domain concept? Check the "Owns" column.
2. **Place ALL domain artifacts in the owning app** -- migrations, schemas, entities, policies, use cases, repositories, domain events.
3. **Place interface artifacts in the owning `_web`/`_api` app** -- LiveViews, controllers, feature files.
4. **If UI renders in another app's shell** -- the owning app exposes a public facade API; the rendering app calls it. The rendering app does NOT own the domain logic.
5. **Never use another app's Repo** -- if you need data from another app, call its public API.
6. **Domain events live in the emitting app** -- the app that produces the event defines the struct and publishes it. Event infrastructure lives in `perme8_events`.

## Agents and Skills

This repo uses two layers of automation:

- **Subagents** are focused workers used through the Task tool (research, planning, implementation, BDD translation).
- **Skills** are reusable workflows that chain multiple steps and often delegate to subagents.

Use this rule of thumb:

1. Use a **skill** when the request matches an end-to-end workflow (ticket pickup, CRUD flows, execute plan, PR review, finalize).
2. Use a **subagent** when you need a specific unit of work (explore codebase, produce a ticket, architect a plan, implement via TDD, translate BDD).
3. For complex work, **compose them**: skill orchestrates, subagents execute specialized steps.

### Subagents (Task Tool)

- **general** -- broad multi-step execution and research; good default when no specialist is clearly better.
- **explore** -- fast codebase discovery (files, symbols, flows). Use for read-only investigations and impact analysis.
- **ticket** -- interviews and structures requirements into a purely conceptual ticket (behaviours and expectations, no code or implementation detail) for downstream planning.
- **architect** -- converts requirements/ticket into a phased TDD implementation plan.
- **phoenix-tdd** -- implements Elixir/Phoenix/LiveView changes using strict Red-Green-Refactor.
- **typescript-tdd** -- implements TypeScript/Vitest (including LiveView hooks and channel clients) using strict TDD.
- **exo-bdd-browser** -- translates scenarios into browser-focused Playwright BDD features.
- **exo-bdd-http** -- translates scenarios into HTTP/API-focused Playwright BDD features.
- **exo-bdd-security** -- translates scenarios into security-focused BDD features (ZAP adapter).
- **exo-bdd-cli** -- translates scenarios into CLI-focused BDD features (Bun CLI adapter).
- **exo-bdd-graph** -- translates scenarios into architecture/dependency graph BDD features (Neo4j adapter).

### Skill Catalog (Workflow Layer)

#### Orchestration

- **Pick Up Ticket** -- starts from a GitHub issue, classifies work type, and routes to the right CRUD workflow. Use when asked to "work on" an existing ticket.
- **Create Ticket** -- interviews users to gather comprehensive product requirements and creates a structured GitHub issue to brief the architect agent. Applies the owning app label and links as a sub-issue where applicable.

#### CRUD Workflows

- **CRUD Create** -- full new-feature workflow with ownership checks, branch creation, BDD generation, draft PR, architecture, and implementation.
- **CRUD Read** -- read-only research/spike workflow; no code changes, no branch/PR, reports findings.
- **CRUD Update** -- bug fix/refactor/chore/docs workflow with impact analysis, regression baseline, and implementation path based on scope.
- **CRUD Delete** -- deprecation/removal workflow with dependency scan, staged teardown, and cleanup.

#### Planning and Delivery

- **Execute Plan** -- executes an existing phased plan end-to-end (implementation, commits, PR lifecycle, CI, review loop).
- **Commit and PR** -- handles branch/commit/push/PR mechanics when implementation is already done or managed elsewhere.
- **Handle Merge Conflict** -- resolves merge conflicts on a PR branch by understanding the PR's purpose, linked ticket, and ticket context. Analyzes both sides of each conflict to determine intent, compares recency and correctness, and produces a resolution that preserves all new functionality from both branches while matching the codebase's current style.
- **Finalize** -- runs quality gates before handoff: tests/checks, documentation sync, acceptance reconciliation, and follow-up issues.

#### Review and Feedback

- **Review PR** -- performs automated multi-specialist PR review and posts inline feedback.
- **Address PR Comments** -- resolves review comments, commits fixes, replies on GitHub, and rechecks CI.

#### Documentation and Testing

- **Check Documentation** -- verifies and fixes docs/API docs impacted by changes (`@moduledoc`, `@doc`, JSDoc, AGENTS/readmes/ownership docs).
- **Generate Exo-BDD Features** -- creates browser/http/security BDD feature files from a ticket (early-pipeline or post-plan mode).
- **Run Tests** -- executes Exo-BDD and unit/integration test suites across umbrella apps with troubleshooting guidance.

### Recommended Usage Patterns

- **New feature from idea/ticket:** `CRUD Create` -> `Execute Plan` -> `Finalize`.
- **Bug fix or refactor:** `CRUD Update` (and `Finalize` for handoff quality checks).
- **Research-only request:** `CRUD Read` (delegates to `explore`).
- **Plan-first request:** `ticket` -> `architect` -> `Execute Plan`.
- **PR quality loop:** `Review PR` -> `Address PR Comments` -> `Finalize`.
- **PR with merge conflicts:** `Handle Merge Conflict` (then resume the normal PR flow).
- **BDD-first delivery:** `Generate Exo-BDD Features`, then implement with `phoenix-tdd`/`typescript-tdd` as appropriate.

### Guardrails for Agent/Skill Use

- Always consult `docs/app_ownership.md` before placing code, generating plans, or creating feature files.
- Prefer workflow skills for lifecycle consistency (branch/PR hygiene, CI handling).
- Use specialist subagents over `general` when the task clearly matches a specialty.
- Keep `CRUD Read` strictly read-only.
- Route GitHub operations through `gh` with the correct token identity described above.
