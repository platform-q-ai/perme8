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
  seed?: string           // Command to run after server is healthy (e.g. DB seeds)
  healthCheckPath?: string // URL path to poll (default: "/")
  startTimeout?: number   // Max wait for healthy (ms, default: 30000)
}
```

### Servers

The `servers` array lets exo-bdd manage the full server lifecycle:

1. Starts each server via its `command`
2. Polls `http://localhost:{port}{healthCheckPath}` until a response arrives (any status)
3. Runs the `seed` command (if provided) -- useful for loading test fixtures
4. Runs all Cucumber scenarios
5. Stops each server on completion (or on error)

### Variables

Config-level `variables` are injected into every scenario's `TestWorld` before steps run. Use them to pass API keys, tokens, or environment-specific values without hardcoding them in feature files:

```gherkin
# In your .feature file -- reference config variables with ${name}
When I set header "Authorization" to "Bearer ${api-token}"
```

Variables set in the config are merged with any set via `Given I set variable` steps. Step-level variables take precedence.

### Timeout

The `timeout` field sets the default Cucumber step timeout in milliseconds. The Cucumber default is 5000ms, which is too short for operations like OWASP ZAP active scans. Set it higher when using the security adapter:

```ts
timeout: 300_000 // 5 minutes -- needed for active security scans
```

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

- `When I navigate to {string}` / `When I click on {string}`
- `When I type {string} into {string}` / `When I select {string} from {string}`
- `Then I should see {string}` / `Then the element {string} should be visible`
- Screenshot, page title, URL assertions

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
bun run tools/exo-bdd/src/cli/index.ts run --config <path-to-config> [cucumber-js args...]
```

| Flag | Alias | Description |
|------|-------|-------------|
| `--config` | `-c` | Path to `exo-bdd-*.config.ts` file (required) |

Additional arguments are passed through to cucumber-js (e.g., `--tags`, `--format`).

## Mix Integration

The `mix exo_test` task wraps the CLI runner for Elixir projects:

```bash
mix exo_test --config apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts
mix exo_test -c apps/jarga_web/test/bdd/exo-bdd-jarga-web.config.ts -t @smoke
```

| Flag | Alias | Description |
|------|-------|-------------|
| `--config` | `-c` | Path to config file (required) |
| `--tag` | `-t` | Cucumber tag expression |

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
