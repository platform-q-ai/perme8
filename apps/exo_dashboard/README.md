# ExoDashboard

A local development tool that provides a single-pane view of all BDD features across the perme8 umbrella. Browse the full feature catalog, trigger test runs per-app/per-feature/per-scenario, and watch results stream in real time.

## Ports

- **Dev:** 4010
- **Test:** 4011

## UI

The dashboard uses a sidebar layout with two main views:

### Feature Overview (`/`)

A collapsible tree view of all discovered features, grouped by app:

```
App > Feature > Scenario
```

- Filter by adapter type (Browser, HTTP, Security, CLI, Graph)
- Click a feature name to view its full detail
- Click a scenario name to jump directly to that scenario on the detail page
- Refresh button re-discovers features from disk

### Feature Detail (`/features/*uri`)

Shows the full content of a single `.feature` file:

- Feature name, description, and tags
- All scenarios with their Gherkin steps
- Rules with nested scenarios
- Anchor-based deep linking (`#scenario-name`) for scroll-to-scenario

## Architecture

No database -- all state is ephemeral (ETS/GenServer). No auth required -- local dev tool only.

### Contexts

- **ExoDashboard.Features** -- Feature catalog discovery and Gherkin parsing
- **ExoDashboard.TestRuns** -- Test execution orchestration and Cucumber Message ingestion

### Data Flow

1. **Feature discovery:** Scans `apps/*/test/features/**/*.feature` files, parses them via `@cucumber/gherkin` (Node.js port), groups by app and adapter type
2. **Test execution:** User triggers a run from the UI, spawns `exo-bdd run` with `--format message:<path>.ndjson`, streams results via PubSub
3. **Result ingestion:** Parses Cucumber Message envelopes from NDJSON, matches back to feature catalog by pickle IDs

### Key Infrastructure

| Component | Purpose |
|-----------|---------|
| `GherkinParser` | Port-based parser using `@cucumber/gherkin` npm package (30s timeout) |
| `FeatureFileScanner` | Disk scanner for `.feature` files via `Path.wildcard/1` |
| `ResultStore` | ETS-backed GenServer for test run state (supervised) |
| `RunExecutor` | Spawns bun/exo-bdd CLI processes via `Task.start/1` |
| `NdjsonWatcher` | Tails NDJSON output files with line buffering, broadcasts via PubSub |

## Dependencies

- `Jarga.PubSub` (shared PubSub from the jarga app)
- `@cucumber/gherkin` and `@cucumber/messages` (npm, in `priv/gherkin_parser/`)
- `tools/exo-bdd` (test runner)

## Setup

```bash
# Install Gherkin parser deps (first time only)
cd apps/exo_dashboard/priv/gherkin_parser && bun install
```

## Usage

```bash
# Start the dashboard (included in umbrella phx.server)
mix phx.server

# Or start standalone
cd apps/exo_dashboard && mix phx.server
```

Visit [localhost:4010](http://localhost:4010).

## Testing

```bash
# Unit tests (no external deps needed)
mix test apps/exo_dashboard --exclude external

# All tests including parser integration (requires bun)
mix test apps/exo_dashboard
```

## Known Limitations

- No exo-bdd browser tests yet -- the LiveView unit tests use mock catalogs, so bugs in the real discovery-to-render pipeline (e.g., path resolution) are not caught
- `ProcessEnvelope` uses plain maps instead of domain entity structs for test case results
- `ResultStoreBehaviour` lives in the infrastructure layer rather than the application/ports layer
- No max idle timeout on `NdjsonWatcher` -- zombie watchers possible if a test run never finishes
- Feature discovery is re-run on every page load (no caching)
