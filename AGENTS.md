# AGENTS.md

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
