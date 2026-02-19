# AGENTS.md

## GitHub Identity & Authentication

All agent operations (commits, PRs, issues, project board updates) MUST be attributed to the `perme8[bot]` GitHub App identity.

### Git Commits

Local git config is set to the bot identity — no extra steps needed:
- `user.name`: `perme8[bot]`
- `user.email`: `262472400+perme8[bot]@users.noreply.github.com`

### GitHub API / `gh` CLI Operations

Set `GH_TOKEN` before any `gh` command so PRs, issues, and project updates are attributed to `perme8[bot]`:

```bash
export GH_TOKEN=$(~/.config/perme8/get-token)
```

The token is short-lived (9 minutes). Re-generate if a command fails with a 401.

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

## Skills

### Orchestration Skills

- **Pick Up Ticket** -- picks up a GitHub issue, classifies the work type (feature, bug, refactor, spike, removal), and routes to the appropriate CRUD workflow. Manages board status and finalization. Use `/pick-up-ticket`.
- **Create Issue** -- orchestrates fully-populated GitHub issue creation with project board fields (Status, Priority, Size, Iteration, App/Tool) and parent linking. Use `/create-issue`.

### CRUD Skills

- **CRUD Create** -- implements new features from a ticket or direct description. Triages scope (Full/Medium/Micro) and delegates to PRD + Architect + Execute Plan, Architect + Execute Plan, or direct TDD.
- **CRUD Read** -- handles research spikes and exploration. Strictly read-only. Posts findings as a comment on the ticket.
- **CRUD Update** -- modifies existing functionality (bug fix, refactor, chore, docs). Runs impact analysis, regression baseline, and TDD.
- **CRUD Delete** -- removes or deprecates features. Scans dependencies, determines migration strategy, and executes staged removal.

### Workflow Skills

- **Execute Plan** -- implements an existing architectural plan end-to-end with commits, PR, CI, review.
- **Finalize** -- reusable finalization and quality gate: pre-commit validation, test coverage verification, PRD reconciliation, documentation checks, and follow-up issue creation. Use `/finalize`.
- **Commit and PR** -- git workflow: branch, incremental commits, pre-commit checks, push, PR creation, CI monitoring.

### Review Skills

- **Review PR** -- automated code review with 8 parallel specialist workers and inline comments on a GitHub PR.
- **Address PR Comments** -- reads and resolves review comments with fix commits and GitHub replies.

### Testing Skills

- **Generate Exo-BDD Features** -- generates domain-specific BDD feature files (browser, HTTP, security) from a PRD.

## Principles

- Tests first -- always write tests before implementation
- Boundary enforcement -- `mix boundary` catches violations
- SOLID principles
- Clean Architecture -- Domain > Application > Infrastructure > Interface
