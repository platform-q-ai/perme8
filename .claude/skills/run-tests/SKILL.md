---
name: Run Tests
description: "Runs exo-bdd tests (browser, HTTP, security, CLI) and Elixir/JS unit tests for any app in the umbrella. Covers test commands, tag filtering, failure debugging, and LiveView testing tips. Triggers: run tests, run exo tests, run browser tests, run security tests, run http tests, exo-bdd, test suite, run test, execute tests, check tests."
---

# Run Tests

Commands and tips for running the test suites in this umbrella project.

## Exo-BDD Tests (browser, HTTP, security, CLI)

### Quick Reference

```bash
# Run all adapters for an app
mix exo_test --name <app-name>

# Run a single adapter
mix exo_test --name <app-name> --adapter <adapter>

# Run with tag filter
mix exo_test --name <app-name> --adapter <adapter> --tag "@smoke"
```

### Browser Tests

```bash
# jarga-web browser suite
mix exo_test --name jarga-web --adapter browser

# identity browser suite
mix exo_test --name identity --adapter browser

# Tag a feature or scenario with @smoke, then run only that
# (via CLI runner -- supports --tags flag)
cd tools/exo-bdd && bun run src/cli/index.ts run \
  --config ../../apps/jarga_web/test/exo-bdd-jarga-web.config.ts \
  --adapter browser --tags "@smoke"
```

### HTTP Tests

```bash
# agents (Knowledge MCP) HTTP suite
mix exo_test --name agents --adapter http

# Or via CLI runner directly
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts --adapter http

# With tag filter
bun run tools/exo-bdd/src/cli/index.ts run \
  --config apps/agents/test/exo-bdd-agents.config.ts \
  --adapter http --tags "@smoke"
```

### Security Tests (ZAP scanning)

Run OWASP ZAP security scans against any app with `*.security.feature` files:

```bash
# jarga-web security suite
mix exo_test --name jarga-web --adapter security

# identity security suite
mix exo_test --name identity --adapter security

# With tag filter
mix exo_test --name jarga-web --adapter security --tag "@smoke"
```

Security tests require Docker (ZAP runs as a container). The exo-bdd security adapter manages the ZAP container lifecycle automatically. Timeout is 300s per step to accommodate active scans.

### CLI Tests

```bash
# alkali CLI suite
mix exo_test --name alkali --adapter cli
```

## Unit Tests

### Elixir (ExUnit)

```bash
# Full umbrella suite
mix test

# Single app
mix test apps/<app_name>/test

# Single file
mix test apps/<app_name>/test/path/to/test.exs

# Single test by line number
mix test apps/<app_name>/test/path/to/test.exs:42
```

### JavaScript (Vitest)

```bash
# Run from the assets directory
npm test --prefix apps/jarga_web/assets

# Or directly
cd apps/jarga_web/assets && npx vitest run
```

## Pre-commit Checks

```bash
mix precommit
```

Runs: credo, boundary check, behaviour check, step linter, CI sync check, asset build, JS tests, and the full Elixir test suite.

## Tips and Troubleshooting

### LiveView Critical Pattern

Always add `I wait for network idle` after navigating to a LiveView page before interacting with `phx-*` elements. See `tools/exo-bdd/README.md` "Phoenix LiveView Tips".

### Asset Rebuild

The jarga-web exo-bdd config uses the `setup` field to run `mix assets.build` before the test server starts. No manual asset rebuild is needed.

### Failure Artifacts

When browser tests fail, screenshots and HTML are saved to `tools/exo-bdd/test-failures/`. Always check these before debugging -- they show exactly what the browser rendered.

### DaisyUI Drawer Selectors

The chat panel has two `.navbar` elements (topbar + panel header). Use `.drawer-content > .navbar label[for='...']` to target the topbar toggle, not `.navbar label[for='...']` which matches both. See `tools/exo-bdd/README.md` "Troubleshooting" for more.

### CI Sync Check

`mix check.ci_sync` validates that every exo-bdd config+domain pair with feature files on disk has a corresponding CI matrix entry. This is included in `mix precommit`.
