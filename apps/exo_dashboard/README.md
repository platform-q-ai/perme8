# ExoDashboard

A local development tool that provides a single-pane view of all BDD features across the perme8 umbrella. Browse the full feature catalog, trigger test runs per-app/per-feature/per-scenario, and watch results stream in real time.

## Ports

- **Dev:** 4010
- **Test:** 4011

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
| `GherkinParser` | Port-based parser using `@cucumber/gherkin` npm package |
| `FeatureFileScanner` | Disk scanner for `.feature` files via `Path.wildcard/1` |
| `ResultStore` | ETS-backed GenServer for test run state |
| `RunExecutor` | Spawns bun/exo-bdd CLI processes |
| `NdjsonWatcher` | Tails NDJSON output files, broadcasts via PubSub |

## Dependencies

- `Jarga.PubSub` (shared PubSub from the jarga app)
- `@cucumber/gherkin` and `@cucumber/messages` (npm, in `priv/gherkin_parser/`)
- `tools/exo-bdd` (test runner)

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
# Run exo_dashboard tests
mix test apps/exo_dashboard/test/

# Install Gherkin parser deps (first time only)
cd apps/exo_dashboard/priv/gherkin_parser && bun install
```
