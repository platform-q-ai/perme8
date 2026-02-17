# Exo-BDD

BDD testing framework with built-in [Cucumber](https://cucumber.io/) step definitions for HTTP, Browser, CLI, Graph, and Security testing. Built on Clean Architecture principles.

## Quick Start

### 1. Initialize a new project config

```bash
bun run tools/exo-bdd/src/cli/index.ts init --name jarga-web --dir apps/jarga_web/test/bdd
```

This creates:
- `apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts` -- project config
- `apps/jarga_web/test/bdd/features/` -- directory for `.feature` files

### 2. Configure adapters

Edit the generated config to enable the adapters you need:

```ts
import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './features/**/*.feature',
  adapters: {
    http: {
      baseURL: 'http://localhost:4000',
    },
  },
})
```

A more complete example with server management, variables, and timeout:

```ts
import { defineConfig } from 'exo-bdd'

export default defineConfig({
  features: './features/**/*.feature',

  // Start/stop a server around the test run
  servers: [
    {
      name: 'my-api',
      command: 'mix phx.server',
      port: 4005,
      healthCheckPath: '/api/health',
      seed: 'mix run priv/repo/seeds.exs',
      env: { MIX_ENV: 'test' },
    },
  ],

  // Pre-seed variables available as ${name} in feature steps
  variables: {
    'api-token': 'tok_abc123',
    'admin-token': 'tok_admin456',
  },

  // Global Cucumber step timeout (ms). Increase for slow scans.
  timeout: 300_000,

  adapters: {
    http: { baseURL: 'http://localhost:4005' },
    security: { zapUrl: 'http://localhost:8080' },
  },
})
```

### 3. Write features

Create `.feature` files in the `features/` directory using standard Gherkin syntax. Exo-BDD provides built-in step definitions for all adapter domains -- no custom step code needed for common operations.

### 4. Run tests

```bash
# Via the CLI runner
bun run tools/exo-bdd/src/cli/index.ts run --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts

# Via the mix task
mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts

# With tag filters
mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts --tag @smoke
```

## Architecture

Exo-BDD follows Clean Architecture with four layers:

```
src/
  domain/          # Entities, value objects, errors (zero dependencies)
  application/     # Ports (interfaces), services, config schema
  infrastructure/  # Concrete adapter implementations
  interface/       # Cucumber steps, hooks, world
```

- **Domain** -- `HttpResponse`, `CommandResult`, `GraphNode`, `SecurityAlert`, `Variable`, `RiskLevel`, `JsonPath`
- **Application** -- Port interfaces (`HttpPort`, `BrowserPort`, `CliPort`, `GraphPort`, `SecurityPort`), `VariableService`, `InterpolationService`, `ExoBddConfig`
- **Infrastructure** -- `PlaywrightHttpAdapter`, `PlaywrightBrowserAdapter`, `BunCliAdapter`, `Neo4jGraphAdapter`, `ZapSecurityAdapter`, `AdapterFactory`
- **Interface** -- Cucumber step definitions, lifecycle hooks, `TestWorld`

## Configuration

The `ExoBddConfig` interface:

```ts
interface ExoBddConfig {
  features?: string | string[]    // Glob(s) to .feature files
  servers?: ServerConfig[]        // Servers to manage around the test run
  variables?: Record<string, string> // Variables pre-seeded into every scenario
  timeout?: number                // Global Cucumber step timeout (ms)
  adapters: {
    http?: HttpAdapterConfig      // HTTP API testing (Playwright)
    browser?: BrowserAdapterConfig // Browser UI testing (Playwright)
    cli?: CliAdapterConfig        // CLI command testing (Bun shell)
    graph?: GraphAdapterConfig    // Graph database testing (Neo4j)
    security?: SecurityAdapterConfig // Security scanning (OWASP ZAP)
  }
}

interface ServerConfig {
  name: string            // Display name for logs
  command: string         // Shell command to start the server
  port: number            // Port to health-check against
  workingDir?: string     // CWD for the command (relative to config file)
  env?: Record<string, string> // Environment variables
  setup?: string          // Command to run before starting the server (e.g. asset build)
  seed?: string           // Command to run after server is healthy (e.g. DB seeds)
  healthCheckPath?: string // URL path to poll (default: "/")
  startTimeout?: number   // Max wait for healthy (ms, default: 30000)
}
```

### Servers

The `servers` array lets exo-bdd manage the full server lifecycle:

1. Runs the `setup` command (if provided) -- useful for asset compilation
2. Starts each server via its `command`
3. Polls `http://localhost:{port}{healthCheckPath}` until a response arrives (any status)
4. Runs the `seed` command (if provided) -- useful for loading test fixtures
5. Runs all Cucumber scenarios
6. Stops each server on completion (or on error)

### Variables

Config-level `variables` are injected into every scenario's `TestWorld` before steps run. Use them to pass API keys, tokens, or environment-specific values without hardcoding them in feature files:

```gherkin
# In your .feature file -- reference config variables with ${name}
When I set header "Authorization" to "Bearer ${api-token}"
```

Variables set in the config are merged with any set via `Given I set variable` steps. Step-level variables take precedence.

### Timeout

The `timeout` field sets the default Cucumber **per-step** timeout in milliseconds. If any single step exceeds this, the scenario is aborted.

```ts
timeout: 10_000  // 10s -- good for browser/HTTP tests (Playwright assertions fail at 5s)
timeout: 300_000 // 5 minutes -- needed for active security scans
```

Keep this low for browser tests (10s) so failing scenarios abort quickly. Playwright's built-in assertion timeout (5s) catches missing elements; the Cucumber timeout is the outer guard.

### Adapter Options

| Adapter | Required Fields | Optional Fields |
|---------|----------------|-----------------|
| `http` | `baseURL` | `timeout`, `headers`, `auth` |
| `browser` | `baseURL` | `headless`, `viewport`, `screenshot`, `video` |
| `cli` | (none) | `workingDir`, `env`, `timeout`, `shell` |
| `graph` | `uri`, `username`, `password` | `database` |
| `security` | `zapUrl` | `zapApiKey`, `pollDelayMs`, `scanTimeout` |

### Top-level Options

| Field | Type | Description |
|-------|------|-------------|
| `features` | `string \| string[]` | Glob(s) to `.feature` files |
| `servers` | `ServerConfig[]` | Servers to start/stop around the test run |
| `variables` | `Record<string, string>` | Variables injected into every scenario as `${name}` |
| `timeout` | `number` | Default Cucumber step timeout in ms (default: 5000) |

## Available Step Definitions

### HTTP Steps

- `Given the base URL is {string}` / `Given the request header {string} is {string}`
- `When I send a GET/POST/PUT/PATCH/DELETE request to {string}`
- `Then the response status should be {int}` / `Then the response body should contain {string}`
- JSON path assertions, array length checks, header checks

### Browser Steps

- **Navigation**: `I navigate to {string}`, `I am on {string}`, `I reload the page`, `I go back`, `I go forward`
- **Clicking**: `I click {string}` (CSS selector), `I click the {string} button` / `link` (text match), `... and wait for navigation` variants
- **Forms**: `I fill {string} with {string}`, `I type {string} into {string}`, `I select {string} from {string}`, `I clear {string}`, `I check/uncheck {string}`
- **Waiting**: `I wait for {string} to be visible/hidden`, `I wait for {int} seconds`, `I wait for network idle`, `I wait for the page to load`
- **Text assertions**: `I should see {string}`, `I should not see {string}`
- **Element assertions**: `{string} should be visible/hidden`, `{string} should exist/not exist`, `{string} should be enabled/disabled`, `{string} should have text/value/class {string}`
- **Page assertions**: `the URL should contain {string}`, `the page title should contain {string}`, `there should be {int} {string} elements`
- **Storage**: `I store the text of {string} as {string}`, `I store the URL as {string}`
- **Other**: `I take a screenshot`, `I hover over {string}`, `I press {string}`, `I upload {string} to {string}`

#### Phoenix LiveView Tips

LiveView pages use a websocket connection that initializes after the initial page load. Forms with `phx-submit` won't work until the socket connects.

- **Always** add `I wait for network idle` after navigating to a LiveView page and before interacting with forms or `phx-*` elements.
- LiveView `navigate` links (client-side patch) don't trigger a full page load. Use `I click the {string} link` + `I wait for network idle` instead of `I click the {string} link and wait for navigation`.
- `I wait for the page to load` only waits for the initial HTTP load event, not the LiveView socket. Use `I wait for network idle` when you need the socket connected.

### CLI Steps

- `When I run the command {string}` / `When I run {string} with args {string}`
- `Then the exit code should be {int}` / `Then the output should contain {string}`
- Environment variable setup, working directory, timeout control

### Graph Steps

- `Given I query the graph with {string}` / `When I select nodes of type {string}`
- `Then I should find {int} nodes` / `Then node {string} should have property {string}`
- Dependency assertions, cycle detection, layer analysis

### Security Steps

- `When I spider the target {string}` / `When I run an active scan on {string}`
- `Then there should be no alerts with risk {string} or higher`
- Header checks, SSL/TLS verification, alert filtering

### Variable Steps

- `Given I set variable {string} to {string}` / `Given I set variable {string} to value {int}`
- `Then variable {string} should equal {string}`
- Variable interpolation in all step parameters via `{variable_name}`

## CLI Commands

### `init` -- Scaffold a new project

```bash
bun run tools/exo-bdd/src/cli/index.ts init --name <project-name> [--dir <target-directory>]
```

| Flag | Alias | Description |
|------|-------|-------------|
| `--name` | `-n` | Project name (required) -- used in config file name |
| `--dir` | `-d` | Target directory (defaults to cwd) |

### `run` -- Execute BDD tests

```bash
bun run tools/exo-bdd/src/cli/index.ts run --config <path-to-config> [--tags <expression>] [--adapter <type>]
```

| Flag | Alias | Description |
|------|-------|-------------|
| `--config` | `-c` | Path to `exo-bdd-*.config.ts` file (required) |
| `--tags` | `-t` | Cucumber tag expression (ANDed with config-level `tags`) |
| `--adapter` | `-a` | Filter feature files by adapter type (e.g. `browser`, `http`, `cli`, `security`, `graph`) |

The `--adapter` flag narrows which feature files are executed based on their filename suffix. For example, `--adapter browser` runs only `*.browser.feature` files. Generic `*.feature` globs are rewritten to match the specified adapter, and globs for other adapters are excluded.

Additional arguments are passed through to cucumber-js (e.g., `--format`).

## Mix Integration

The `mix exo_test` task wraps the CLI runner for Elixir projects:

```bash
# Auto-discover and run all exo-bdd configs
mix exo_test

# Filter by app name (substring match)
mix exo_test --name entity

# Filter scenarios by tag (ANDed with config-level tags)
mix exo_test --tag "not @security"

# Filter by adapter type (only run browser features)
mix exo_test --name identity --adapter browser

# Combine: run only ERM HTTP tests
mix exo_test --name entity --tag "not @security"

# Run a specific config file
mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts
```

| Flag | Alias | Description |
|------|-------|-------------|
| `--config` | `-c` | Path to config file (auto-discovers if omitted) |
| `--tag` | `-t` | Cucumber tag expression (ANDed with config-level `tags`) |
| `--name` | `-n` | Substring filter for auto-discovered config names |
| `--adapter` | `-a` | Filter feature files by adapter type (`browser`, `http`, `cli`, `security`, `graph`) |

## Failure Artifacts

When a browser scenario fails, exo-bdd automatically saves artifacts to `test-failures/` (relative to the exo-bdd working directory):

- `{scenario-slug}.png` -- full-page screenshot at point of failure
- `{scenario-slug}.html` -- complete page HTML source
- `{scenario-slug}.meta.txt` -- URL and scenario name

These are invaluable for debugging -- **always check the screenshot and HTML** before guessing at what might be wrong. The HTML file can be opened in a browser to inspect the DOM structure, and is especially useful for identifying which elements Playwright is matching.

The `test-failures/` directory is cleaned on each run but not deleted between runs, so old artifacts from a previous session persist until overwritten. It is gitignored.

## Troubleshooting

### Asset changes not taking effect in tests

`mix phx.server` in `MIX_ENV=test` does **not** run asset watchers (esbuild/tailwind). It serves whatever is in `priv/static/assets/`.

The recommended fix is to add a `setup` command to your server config so assets are rebuilt automatically before every test run:

```typescript
servers: [{
  name: 'jarga-web',
  command: 'mix phx.server',
  setup: 'cd apps/jarga_web && mix assets.build',  // runs before server starts
  // ...
}]
```

If you don't use `setup`, you must manually rebuild after changing CSS or JS files:

```bash
cd apps/jarga_web && mix assets.build
```

### Playwright click timeouts on DaisyUI drawers

DaisyUI's `.drawer-side` uses `position: fixed; inset: 0` covering the entire viewport. When the drawer is closed, DaisyUI hides it with `visibility: hidden` and `pointer-events: none`. While browsers correctly ignore it for user interaction, Playwright's actionability checks can see the fixed-position element in the stacking context and may refuse to click through it.

**Solutions:**
1. Ensure the drawer element is truly not covering the click target (check the screenshot artifact)
2. Use `I force click {string}` to bypass Playwright's actionability checks
3. Use `I js click {string}` to trigger `el.click()` via `evaluate()` for pure DOM-level clicks

### Selectors matching multiple elements

Playwright's `page.click(selector)` resolves the selector and picks the **first** matching element. If multiple elements match, it may pick a hidden one and report "Element is not visible". This is a common problem with DaisyUI drawers where the same `label[for=...]` appears in both the topbar and inside the drawer panel.

**Debug approach:**
1. Check the failure HTML artifact for the element you're trying to click
2. Search for all elements matching your selector -- there may be duplicates
3. Use a more specific selector to uniquely identify the target element

**Example:**
```gherkin
# BAD: Matches label in topbar AND label inside chat panel header
When I click ".navbar label[for='chat-drawer-global-chat-panel']"

# GOOD: Scoped to the admin drawer-content's navbar only
When I click ".drawer-content > .navbar label[for='chat-drawer-global-chat-panel']"
```

### JS hooks changing initial state

Phoenix LiveView hooks (`phx-hook`) run JavaScript after the element mounts. These hooks can programmatically change element state (e.g., checking a checkbox, setting `display`, modifying classes) in ways that aren't visible in the server-rendered HTML template.

**If an element's runtime state doesn't match the template:**
1. Check the `phx-hook` attribute on the element
2. Find the corresponding hook in `assets/js/` and read its `mounted()` method
3. Check if it reads from `localStorage`, adjusts for viewport size, or otherwise mutates state

**Example:** The `ChatPanel` hook reads `localStorage('chat-panel-open')` and was previously auto-opening the drawer on desktop viewports. This meant the panel was open even though the template rendered the checkbox as unchecked.

### LiveView pages need network idle waits

Every page in a LiveView app requires `I wait for network idle` after navigation before interacting with `phx-*` elements. The `I wait for the page to load` step only waits for the initial HTTP `load` event, not the LiveView websocket connection.

```gherkin
# CORRECT: Waits for websocket
Given I navigate to "${baseUrl}/app/workspaces"
And I wait for network idle
When I fill "#search" with "test"

# WRONG: Form may not work because socket isn't connected yet
Given I navigate to "${baseUrl}/app/workspaces"
And I wait for the page to load
When I fill "#search" with "test"
```

## Development

```bash
# Install dependencies
bun install

# Run unit tests
bun test

# Run a specific test file
bun test tests/cli/init.test.ts

# Type check
bunx tsc --noEmit
```
