# AGENTS.md

## GitHub Identity & Authentication

Perme8 uses two GitHub App identities:

- `perme8[bot]` for commits, PR creation/updates, issues, project board updates, and PR comment-addressing replies.
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

## Skills

### Orchestration Skills

- **Pick Up Ticket** -- picks up a GitHub issue, classifies the work type (feature, bug, refactor, spike, removal), and routes to the appropriate CRUD workflow. Manages board status and finalization. Use `/pick-up-ticket`.
- **Create Issue** -- orchestrates fully-populated GitHub issue creation with project board fields (Status, Priority, Size, Iteration, App/Tool) and parent linking. Use `/create-issue`.

### CRUD Skills

- **CRUD Create** -- implements new features from a ticket or direct description. Triages scope (Full/Medium/Micro). Creates the implementation branch upfront, generates BDD feature files, opens a draft PR for user review, then continues with architecture and implementation on the same branch after approval. The draft PR is marked ready for review once implementation is complete.
- **CRUD Read** -- handles research spikes and exploration. Strictly read-only. Posts findings as a comment on the ticket.
- **CRUD Update** -- modifies existing functionality (bug fix, refactor, chore, docs). Runs impact analysis, regression baseline, and TDD. For user-facing changes, opens a draft PR with BDD feature files for review before implementation.
- **CRUD Delete** -- removes or deprecates features. Scans dependencies, determines migration strategy, and executes staged removal.

### Workflow Skills

- **Execute Plan** -- implements an existing architectural plan end-to-end with commits, CI, review. Supports receiving an existing branch and draft PR from the calling skill (skips branch/PR creation, marks the draft PR as ready when done), or creating its own branch and PR from scratch.
- **Finalize** -- reusable finalization and quality gate: pre-commit validation, test coverage verification, PRD reconciliation, documentation checks, and follow-up issue creation. Use `/finalize`.
- **Commit and PR** -- git workflow: branch, incremental commits, pre-commit checks, push, PR creation, CI monitoring.

### Review Skills

- **Review PR** -- automated code review with 9 parallel specialist workers (including documentation checks) and inline comments on a GitHub PR.
- **Address PR Comments** -- reads and resolves review comments with fix commits and GitHub replies.

### Documentation Skills

- **Check Documentation** -- verifies code and project documentation are current for changes made. Checks `@moduledoc`, `@doc`, JSDoc on new public APIs, and ensures AGENTS.md, `docs/umbrella_apps.md`, READMEs, and `docs/app_ownership.md` are updated when structure changes. Operates in fix mode (Finalize) or review mode (Review PR).

### Testing Skills

- **Generate Exo-BDD Features** -- generates domain-specific BDD feature files (browser, HTTP, security) from a PRD. Supports early-pipeline mode (before architect, business-language steps) and post-plan mode (after architect, concrete implementation details).
