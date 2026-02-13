# AGENTS.md

## Project Structure

Elixir Phoenix umbrella project. **MUST** read `docs/umbrella_apps.md` before any development work.

## Workflow

Specialized subagents maintain code quality, architectural integrity, and TDD discipline:

- `docs/instructions/orchestrated-workflow.md`
- `docs/instructions/subagent-coordination.md`
- `docs/instructions/subagent-reference.md`
- `docs/instructions/quick-start-example.md`

## Reference Docs

- `docs/prompts/architect/FEATURE_TESTING_GUIDE.md`
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md`
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md`
- `docs/prompts/typescript/TYPESCRIPT_DESIGN_PRINCIPLES.md`

## Subagents

- `.opencode/agent/prd.md`
- `.opencode/agent/architect.md`
- `.opencode/agent/phoenix-tdd.md`
- `.opencode/agent/typescript-tdd.md`

## Principles

- Tests first -- always write tests before implementation
- Boundary enforcement -- `mix boundary` catches violations
- SOLID principles
- Clean Architecture -- Domain > Application > Infrastructure > Interface
