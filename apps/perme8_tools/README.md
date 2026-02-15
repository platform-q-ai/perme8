# Perme8Tools

Development-time Mix tasks and code quality utilities for the Perme8 platform. Provides linting, validation, and scaffolding tools used during development and in the pre-commit workflow.

## Mix Tasks

### `mix step_linter`

Lints Cucumber BDD step definition files to enforce quality standards.

**Rules enforced:**

| Rule | Description |
|------|-------------|
| No branching | Step definitions must not contain `if`/`case`/`cond` statements |
| No stubs | Steps must not contain stub implementations |
| No sleep calls | Steps must not use `Process.sleep` or `:timer.sleep` |
| Step too long | Individual step definitions must not exceed a configurable line limit |
| File too long | Step definition files must not exceed a configurable line limit |
| Unused context | Step functions must use their context parameter |
| LiveView conventions | Steps must follow LiveView testing conventions |

```bash
mix step_linter
```

### `mix check_behaviours`

Validates that all behaviour implementations correctly implement their declared callbacks.

```bash
mix check_behaviours
```

### `mix scaffold_boundaries`

Scaffolds boundary definitions for modules, helping maintain Clean Architecture layer enforcement.

```bash
mix scaffold_boundaries
```

### `mix exo_test`

Runs the TypeScript-based exo-bdd BDD test suite.

```bash
mix exo_test
```

## Integration with Pre-commit

The `step_linter` task is included in the root-level `mix precommit` alias, running automatically before every commit to catch BDD step quality issues early.

## Dependencies

- Boundary -- compile-time boundary enforcement
- Jason -- JSON parsing for configuration
