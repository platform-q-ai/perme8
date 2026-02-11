# AGENTS.md

## 🏗️ Project Structure: Elixir Phoenix Umbrella

**This is an Elixir Phoenix umbrella project.** Before starting any development work, you **MUST** read `docs/umbrella_apps.md` first to understand:

- The umbrella project structure (`apps/` directory)
- How applications depend on each other (`in_umbrella: true`)
- When to create new apps vs. add modules to existing ones
- Proper app naming and organization
- Centralized configuration approach

**Key principle**: Always think in terms of separate applications within the umbrella. Each app should have a clear, single responsibility.

## 🤖 Orchestrated Development Workflow

**This project uses specialized subagents to maintain code quality, architectural integrity, and TDD discipline.**

For complete workflow documentation, see:

- **Orchestrated Development Workflow**: `docs/instructions/orchestrated-workflow.md`
- **BDD Implementation Workflow**: `docs/instructions/bdd-workflow.md`
- **Quality Assurance Phases**: `docs/instructions/quality-assurance.md`
- **Self-Learning Loop**: `docs/instructions/self-learning-loop.md`
- **Subagent Coordination**: `docs/instructions/subagent-coordination.md`
- **Subagent Reference**: `docs/instructions/subagent-reference.md`
- **Quick Start Example**: `docs/instructions/quick-start-example.md`

## Quick Reference

For detailed documentation on architecture, BDD, TDD practices, and implementation guidelines, see:

📖 **Architecture & Design:**

- `docs/prompts/architect/FEATURE_TESTING_GUIDE.md` - Complete BDD methodology
- `docs/prompts/phoenix/PHOENIX_DESIGN_PRINCIPLES.md` - Phoenix architecture
- `docs/prompts/phoenix/PHOENIX_BEST_PRACTICES.md` - Phoenix conventions
- `docs/prompts/typescript/TYPESCRIPT_DESIGN_PRINCIPLES.md` - Frontend assets architecture

🤖 **Subagent Details:**

- `.opencode/agent/prd.md` - Requirements gathering and PRD creation
- `.opencode/agent/architect.md` - Feature planning process
- `.opencode/agent/phoenix-tdd.md` - Phoenix and LiveView TDD implementation
- `.opencode/agent/typescript-tdd.md` - TypeScript TDD implementation
- `.opencode/agent/fullstack-bdd.md` - Full-stack BDD testing with Cucumber
- `.opencode/agent/test-validator.md` - Test quality validation
- `.opencode/agent/code-reviewer.md` - Code review process

## Key Principles

- ✅ **Tests first** - Always write tests before implementation
- ✅ **Boundary enforcement** - Use `mix boundary` to catch violations
- ✅ **SOLID principles** - Single responsibility, dependency inversion, etc.
- ✅ **Clean Architecture** - Domain → Application → Infrastructure → Interface

There are NO TIME Constraints and NO token limits!
