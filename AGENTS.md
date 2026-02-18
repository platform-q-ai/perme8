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

## Exo-BDD Tests

### Browser Tests (jarga-web)

Run browser tests iteratively by tagging features/scenarios for fast feedback:

```bash
# Full suite
mix exo_test --name jarga-web --adapter browser

# Tag a feature or scenario with @smoke, then run only that
# (via CLI runner -- supports --tags flag)
cd tools/exo-bdd && bun run src/cli/index.ts run \
  --config ../../apps/jarga_web/test/exo-bdd-jarga-web.config.ts \
  --adapter browser --tags "@smoke"
```

### HTTP Tests (agents -- Knowledge MCP)

Run Knowledge MCP HTTP integration tests:

```bash
# Full HTTP suite (26 scenarios)
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

**LiveView critical pattern**: Always add `I wait for network idle` after navigating to a LiveView page before interacting with `phx-*` elements. See `tools/exo-bdd/README.md` "Phoenix LiveView Tips".

**Asset rebuild is automatic**: The jarga-web exo-bdd config uses the `setup` field to run `mix assets.build` before the test server starts. No manual asset rebuild is needed.

**Failure artifacts**: When tests fail, screenshots and HTML are saved to `tools/exo-bdd/test-failures/`. Always check these before debugging -- they show exactly what the browser rendered.

**DaisyUI drawer selectors**: The chat panel has two `.navbar` elements (topbar + panel header). Use `.drawer-content > .navbar label[for='...']` to target the topbar toggle, not `.navbar label[for='...']` which matches both. See `tools/exo-bdd/README.md` "Troubleshooting" for more.

## Principles

- Tests first -- always write tests before implementation
- Boundary enforcement -- `mix boundary` catches violations
- SOLID principles
- Clean Architecture -- Domain > Application > Infrastructure > Interface
