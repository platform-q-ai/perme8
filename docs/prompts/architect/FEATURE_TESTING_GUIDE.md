# Feature Testing Guide

## Overview

Feature tests in this project use **exo-bdd**, a TypeScript-based BDD framework that runs Cucumber feature files against running Phoenix servers via external adapters (HTTP, browser, CLI, graph, security).

All feature tests are **black-box integration tests** — they interact with the application through its external interfaces (HTTP APIs, browser UI, CLI commands) rather than internal Elixir code.

## Framework Reference

- **Full Specification**: `tools/exo-bdd/EXO-BDD-SPEC.md`
- **Quick Start & Config Reference**: `tools/exo-bdd/README.md`
- **Implementation Plan**: `tools/exo-bdd/IMPLEMENTATION-PLAN.md`

## Available Adapters

| Adapter | File Suffix | Purpose | Built-in Steps |
|---------|------------|---------|----------------|
| **HTTP** | `.http.feature` | REST API testing via Playwright | GET/POST/PUT/PATCH/DELETE, headers, auth, JSONPath assertions |
| **Browser** | `.browser.feature` | Web UI testing via Playwright | Navigate, click, fill, type, visibility/content/state assertions |
| **CLI** | `.cli.feature` | Command-line testing via Bun shell | Run commands, stdout/stderr assertions, exit codes, env vars |
| **Graph** | `.graph.feature` | Neo4j graph testing | Layer selection, dependency assertions, Cypher queries |
| **Security** | `.security.feature` | OWASP ZAP vulnerability scanning | Spider, active/passive scans, alert assertions, header checks |

## Running Tests

```bash
# Run all exo-bdd tests across all apps
mix exo_test

# Run for a specific app
mix exo_test --app jarga_api

# Filter by tag
mix exo_test --tag @critical

# Filter by scenario name
mix exo_test --name "Create workspace"
```

## Config Files

Each app that has exo-bdd features has a config file at `apps/<app>/test/exo-bdd-<app>.config.ts`. The config defines:

- **features** — glob patterns for feature files
- **servers** — Phoenix servers to start/stop with health checks and seed scripts
- **variables** — test data (API keys, emails, passwords) interpolated into features via `${name}`
- **adapters** — adapter-specific config (baseURL, headless mode, ZAP docker settings)
- **timeout** — step timeout (300s for security scans, 120s for browser, default for others)

## Seed Data

Test fixtures are provisioned by seed scripts referenced in each config's `server.seed` field:

- `apps/jarga/priv/repo/exo_seeds.exs` — API/ERM test data (users, workspaces, projects, documents, API keys)
- `apps/jarga/priv/repo/exo_seeds_web.exs` — Browser test data (additional users with roles, agents)
- `apps/identity/priv/repo/exo_seeds.exs` — Identity/auth test data

Seed scripts run with `--no-start` against the already-running test server's database.

## Writing Feature Files

Feature files use **only built-in step definitions** — no custom step code is needed. Each adapter has a fixed vocabulary of steps documented in `tools/exo-bdd/EXO-BDD-SPEC.md`.

### Variable Interpolation

Use `${variableName}` in any step to reference config variables:

```gherkin
Given I set bearer token to "${valid-doc-key-product-team}"
When I GET "/api/workspaces/${productTeamSlug}/documents"
```

### Example: HTTP Feature

```gherkin
@http
Feature: Document API
  Background:
    Given I set bearer token to "${valid-doc-key-product-team}"

  Scenario: List workspace documents
    When I GET "/api/workspaces/product-team/documents"
    Then the response status should be 200
    And the response body path "$.data" should be an array
```

### Example: Browser Feature

```gherkin
@browser
Feature: Workspace CRUD
  Scenario: Owner creates a workspace
    Given I navigate to "/users/log-in"
    When I fill "#login_form_password_email" with "${ownerEmail}"
    And I fill "#login_form_password_password" with "${ownerPassword}"
    And I click the "Log in" button
    And I wait for network idle
    And I navigate to "/workspaces"
    And I click the "New Workspace" button
    And I fill "[data-testid='workspace-name']" with "Marketing Team"
    And I click the "Create Workspace" button
    Then I should see "Workspace created successfully"
```

### Example: CLI Feature

```gherkin
@cli
Feature: Build Static Site
  Scenario: Build simple blog
    When I run "mix alkali.build"
    Then the command should succeed
    And stdout should contain "Build completed"
```

## Generating Feature Files

Use the **BDD Feature Translator** skill to generate domain-specific feature files from a PRD. It delegates to specialized subagents:

- `exo-bdd-http` — translates to HTTP adapter perspective
- `exo-bdd-browser` — translates to browser adapter perspective
- `exo-bdd-security` — translates to security adapter perspective
- `exo-bdd-cli` — translates to CLI adapter perspective
- `exo-bdd-graph` — translates to graph adapter perspective

## Key Principles

1. **Black-box testing** — interact only through external interfaces
2. **No custom steps** — use only built-in adapter steps
3. **Seed data over fixtures** — deterministic test data via seed scripts
4. **One adapter per file** — each `.feature` file targets one adapter
5. **Observable assertions** — verify what users/clients can see, not internal state
