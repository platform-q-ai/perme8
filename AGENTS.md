# AGENTS.md

## Project Structure

Elixir Phoenix umbrella project. **MUST** read `docs/umbrella_apps.md` before any development work.

## Reference Docs

- `docs/prompts/architect/FEATURE_TESTING_GUIDE.md`
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md`
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md`
- `docs/prompts/typescript/TYPESCRIPT_DESIGN_PRINCIPLES.md`

## Subagents

- `.opencode/agent/prd.md` -- requirements gathering and PRD creation
- `.opencode/agent/architect.md` -- TDD implementation plans from PRDs
- `.opencode/agent/phoenix-tdd.md` -- Phoenix backend/LiveView implementation via TDD
- `.opencode/agent/typescript-tdd.md` -- TypeScript implementation via TDD

## Skills

- **Build Feature** -- full lifecycle: PRD → Architect → Execute Plan → PR. Use for new features from scratch.
- **Execute Plan** -- implements an existing architectural plan end-to-end with commits, PR, CI, review.
- **Commit and PR** -- git workflow: branch, incremental commits, pre-commit checks, push, PR creation, CI monitoring.
- **PR Reviewer** -- automated code review with inline comments on a GitHub PR.
- **Address PR Comments** -- reads and resolves review comments with fix commits.
- **BDD Feature Translator** -- generates domain-specific feature files (browser, HTTP, security) from a PRD.
- **Update Project** -- creates/updates issues on the Perme8 GitHub Project board with all fields populated. Use `/update-project`.

## Principles

- Tests first -- always write tests before implementation
- Boundary enforcement -- `mix boundary` catches violations
- SOLID principles
- Clean Architecture -- Domain > Application > Infrastructure > Interface
