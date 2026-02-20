# Feature: Exo Dashboard -- Cucumber Feature Dashboard

**GitHub Issue**: #170
**Status**: ⏸ Not Started

## Overview

A local dev-tool LiveView app that provides a single-pane view of all BDD features across the perme8 umbrella. Developers can browse the full feature catalog (parsed from `.feature` files), trigger test runs (per-app, per-feature, or per-scenario), and watch results stream in real time with step-level pass/fail detail.

This plan covers **two codebases**:
1. **Elixir/Phoenix** -- the `exo_dashboard` umbrella app (new)
2. **TypeScript** -- changes to `tools/exo-bdd` (existing) to emit Cucumber Message NDJSON

## UI Strategy

- **LiveView coverage**: 100% -- all UI is server-rendered LiveView
- **TypeScript needed**: Minimal client-side JS for the LiveView socket (standard `app.ts` boilerplate). No custom TypeScript domain/application logic needed on the client; LiveView handles all state, events, and real-time streaming natively via PubSub. One optional hook for NDJSON auto-scroll behavior.

## Affected Boundaries

- **Primary context**: `ExoDashboard` (new umbrella app)
  - `ExoDashboard.Features` -- feature catalog parsing and domain
  - `ExoDashboard.TestRuns` -- test execution orchestration and result ingestion
- **Dependencies**: None (standalone dev tool, no cross-app Elixir deps)
- **External tool dependency**: `tools/exo-bdd` (TypeScript) -- needs `message` formatter support
- **Existing infrastructure used**: `Jarga.PubSub` (shared PubSub for real-time streaming)
- **New context needed?**: Yes -- entirely new umbrella app `exo_dashboard`

## Architecture Decisions

### AD-1: No Database (ETS/In-Memory Only)
This is a dev tool. All state is ephemeral:
- Feature catalog is parsed from disk on mount/refresh
- Test results live in a GenServer (ETS-backed) for the duration of the dev session
- No Ecto, no Repo, no migrations

### AD-2: Gherkin Parsing via Node.js Port
Use `@cucumber/gherkin` npm package called via a Port/Node script. This ensures 100% compatibility with the official Gherkin spec (rules, scenario outlines, data tables, doc strings, tags, i18n). The Elixir side sends file paths, the Node script returns parsed JSON.

### AD-3: Cucumber Messages via NDJSON File + File Watching
When a test run is triggered:
1. Elixir spawns `bun run exo-bdd run --config <path> --format message:<ndjson-path>`
2. A `FileWatcher` GenServer tails the NDJSON file using periodic reads
3. Each parsed envelope is broadcast via `Jarga.PubSub` to subscribing LiveViews
4. This decouples the run process from the dashboard -- works even if the dashboard restarts

### AD-4: Umbrella App Structure
```
apps/exo_dashboard/
  lib/
    exo_dashboard/
      features/                  # Features context
        domain/
          entities/
            feature.ex           # Pure struct: Feature
            scenario.ex          # Pure struct: Scenario
            step.ex              # Pure struct: Step
            rule.ex              # Pure struct: Rule
          policies/
            adapter_classifier.ex  # Classifies features by adapter type from filename
        application/
          use_cases/
            discover_features.ex   # Orchestrates feature file discovery + parsing
            parse_feature_file.ex  # Calls Gherkin parser port
        infrastructure/
          gherkin_parser.ex        # Port-based Gherkin parser (calls Node.js)
          feature_file_scanner.ex  # Scans disk for .feature files
      features.ex                # Public API facade

      test_runs/                 # TestRuns context
        domain/
          entities/
            test_run.ex          # Pure struct: TestRun
            test_case_result.ex  # Pure struct: result for a scenario
            test_step_result.ex  # Pure struct: result for a step
          policies/
            result_matcher.ex    # Matches Cucumber message IDs back to catalog entries
            status_policy.ex     # Derives aggregate status from step results
        application/
          use_cases/
            start_test_run.ex    # Spawns exo-bdd process, sets up NDJSON watcher
            process_envelope.ex  # Parses a single Cucumber Message envelope
        infrastructure/
          run_executor.ex        # Spawns bun/exo-bdd CLI process
          ndjson_watcher.ex      # Tails NDJSON output file, broadcasts via PubSub
          result_store.ex        # ETS-backed GenServer for test run state
      test_runs.ex               # Public API facade

    exo_dashboard/application.ex   # OTP app (Endpoint + ResultStore + PubSub)
    exo_dashboard.ex               # Root module with Boundary config

    exo_dashboard_web/
      endpoint.ex
      router.ex
      telemetry.ex
      live/
        dashboard_live.ex        # Main dashboard LiveView
        feature_detail_live.ex   # Single feature detail view
      components/
        layouts.ex               # Root + app layouts
        core_components.ex       # Shared UI components
        feature_components.ex    # Feature tree, scenario cards
        result_components.ex     # Status badges, step results, progress
      gettext.ex
    exo_dashboard_web.ex         # Web module macros

  assets/
    css/app.css                  # Tailwind 4 + daisyUI (vendored)
    js/app.ts                    # Standard LiveView socket + topbar
    vendor/                      # daisyUI JS, heroicons, topbar

  priv/
    static/                      # Compiled assets
    gherkin_parser/              # Node.js Gherkin parser script
      parse.mjs                  # Reads .feature files, outputs JSON to stdout
      package.json               # @cucumber/gherkin, @cucumber/messages deps

  test/
    exo_dashboard/
      features/...
      test_runs/...
    exo_dashboard_web/
      live/...
    support/

  mix.exs
```

### AD-5: Port Assignments
- Dev: `4010`
- Test: `4011`

---

## Phase 0: exo-bdd TypeScript Changes (typescript-tdd) ⏳

These changes are prerequisites for the dashboard's result ingestion. They modify `tools/exo-bdd/` to support the Cucumber `message` formatter.

### 0.1: Add `ReportConfig` to `ConfigSchema.ts`

- [x] ✓ **RED**: Write test `tools/exo-bdd/src/application/config/ConfigSchema.test.ts`
  - Tests: `ReportConfig` type is accepted by `ExoBddConfig`
  - Tests: `report.message` can be `true`, `false`, or `{ outputDir: string }`
  - Tests: Default `outputDir` resolves to `.exo-bdd-reports/`
- [x] ✓ **GREEN**: Add `report?: ReportConfig` to `ExoBddConfig` in `ConfigSchema.ts`
  ```typescript
  export interface ReportConfig {
    /** Emit Cucumber Messages NDJSON during test runs. */
    message?: boolean | { outputDir?: string }
  }
  ```
- [x] ✓ **REFACTOR**: Ensure backward compatibility -- existing configs without `report` still work

### 0.2: Update `buildCucumberArgs()` to Inject Message Formatter

- [x] ✓ **RED**: Write test `tools/exo-bdd/src/cli/run.test.ts` (extend existing)
  - Tests: When `report.message` is `true`, args include `--format message:<default-path>`
  - Tests: When `report.message` is `{ outputDir: "/tmp/out" }`, args include `--format message:/tmp/out/<timestamp>.ndjson`
  - Tests: When `report.message` is `false` or absent, no `--format message:` arg is added
  - Tests: Message formatter arg coexists with other args (tags, features, etc.)
- [x] ✓ **GREEN**: Update `buildCucumberArgs()` in `tools/exo-bdd/src/cli/run.ts`
  - Accept optional `report` config parameter
  - When message reporting is enabled, append `--format`, `message:<path>` to args
  - Generate timestamped filename: `<outputDir>/<config-name>-<ISO-timestamp>.ndjson`
  - Create outputDir if it doesn't exist
- [x] ✓ **REFACTOR**: Extract formatter arg building into a helper function

### 0.3: Wire Report Config into `runTests()`

- [x] ✓ **RED**: Write integration test `tools/exo-bdd/src/cli/run.integration.test.ts`
  - Tests: `runTests()` with `report.message: true` creates NDJSON output file
  - Tests: NDJSON file contains valid Envelope lines (meta, source, testRunStarted, etc.)
- [x] ✓ **GREEN**: Update `runTests()` in `tools/exo-bdd/src/cli/run.ts`
  - Pass `config.report` to `buildCucumberArgs()` 
  - Ensure outputDir exists before spawning cucumber-js
- [x] ✓ **REFACTOR**: Clean up

### 0.4: Add Dashboard-Triggered Run Support to `mix exo_test`

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/mix/tasks/exo_test_test.exs`
  - Tests: `build_cmd_args/5` accepts `message_output` option and appends `--format message:<path>`
  - Tests: Without `message_output`, no format args are added (backward compatible)
- [ ] ⏸ **GREEN**: Update `Mix.Tasks.ExoTest.build_cmd_args/5` to accept optional `message_output` path
  - When provided, append `--format`, `message:#{message_output}` to the bun args
- [ ] ⏸ **REFACTOR**: Extract common arg-building logic

### Phase 0 Validation
- [x] ✓ All TypeScript tests pass (`bun test` in `tools/exo-bdd/`)
- [ ] ⏸ All Elixir tests pass for `perme8_tools` (`mix test` in `apps/perme8_tools/`)
- [x] ✓ Existing exo-bdd configs still work without `report` field
- [ ] ⏸ Manual smoke test: `mix exo_test --name identity --adapter http` with `report.message: true` produces NDJSON file

---

## Phase 1: Domain + Application (phoenix-tdd)

### 1.1: Feature Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/domain/entities/feature_test.exs`
  - Tests: `Feature.new/1` creates struct with name, description, tags, uri, app, adapter, children (rules/scenarios)
  - Tests: `Feature.new/1` defaults children to `[]`, tags to `[]`
  - Tests: Struct fields are accessible
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/feature.ex`
  - Pure struct with `defstruct`: `[:id, :uri, :name, :description, :tags, :app, :adapter, :language, :children]`
  - `new/1` factory function
  - `@type t` typespec
- [ ] ⏸ **REFACTOR**: Clean up

### 1.2: Scenario Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/domain/entities/scenario_test.exs`
  - Tests: `Scenario.new/1` creates struct with id, name, tags, steps, keyword (Scenario/Scenario Outline), examples, location
  - Tests: Defaults steps to `[]`, tags to `[]`
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/scenario.ex`
  - Pure struct: `[:id, :name, :keyword, :description, :tags, :steps, :examples, :location]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.3: Step Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/domain/entities/step_test.exs`
  - Tests: `Step.new/1` creates struct with id, keyword, keyword_type, text, location, data_table, doc_string
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/step.ex`
  - Pure struct: `[:id, :keyword, :keyword_type, :text, :location, :data_table, :doc_string]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.4: Rule Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/domain/entities/rule_test.exs`
  - Tests: `Rule.new/1` creates struct with id, name, description, tags, children (scenarios)
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/rule.ex`
  - Pure struct: `[:id, :name, :description, :tags, :children]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.5: AdapterClassifier Policy

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/domain/policies/adapter_classifier_test.exs`
  - Tests: `classify/1` extracts adapter from filename: `"login.browser.feature"` -> `:browser`
  - Tests: `classify/1` handles all adapters: `:browser`, `:http`, `:security`, `:cli`
  - Tests: `classify/1` returns `:unknown` for files without adapter suffix (e.g., `"plain.feature"`)
  - Tests: `classify/1` handles paths: `"apps/jarga_web/test/features/login.browser.feature"` -> `:browser`
  - Tests: `app_from_path/1` extracts app name: `"apps/jarga_web/test/features/..."` -> `"jarga_web"`
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/domain/policies/adapter_classifier.ex`
  - `classify/1` -- pure function, regex on filename
  - `app_from_path/1` -- pure function, extracts app name from path
- [ ] ⏸ **REFACTOR**: Clean up

### 1.6: TestRun Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_run_test.exs`
  - Tests: `TestRun.new/1` creates struct with id, config_path, status (:pending), scope (app/feature/scenario), started_at, finished_at, test_cases
  - Tests: `TestRun.start/1` transitions status to `:running` and sets started_at
  - Tests: `TestRun.finish/2` transitions to `:passed` or `:failed` and sets finished_at
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_run.ex`
  - Pure struct: `[:id, :config_path, :status, :scope, :started_at, :finished_at, :test_cases, :progress]`
  - Status transitions: `:pending` -> `:running` -> `:passed` | `:failed`
  - `progress` map: `%{total: 0, passed: 0, failed: 0, skipped: 0, pending: 0}`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.7: TestCaseResult Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_case_result_test.exs`
  - Tests: `TestCaseResult.new/1` creates struct with pickle_id, test_case_id, test_case_started_id, status, step_results, duration, feature_uri, scenario_name
  - Tests: `TestCaseResult.add_step_result/2` appends a step result and recomputes aggregate status
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_case_result.ex`
  - Pure struct: `[:pickle_id, :test_case_id, :test_case_started_id, :status, :step_results, :duration, :feature_uri, :scenario_name, :attempt]`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.8: TestStepResult Entity (Pure Struct)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_step_result_test.exs`
  - Tests: `TestStepResult.new/1` creates struct with test_step_id, status, duration, error_message, exception
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_step_result.ex`
  - Pure struct: `[:test_step_id, :status, :duration_ms, :error_message, :exception]`
  - Status enum: `:passed`, `:failed`, `:pending`, `:skipped`, `:undefined`, `:ambiguous`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.9: StatusPolicy

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/domain/policies/status_policy_test.exs`
  - Tests: `aggregate_status/1` returns `:passed` when all steps passed
  - Tests: `aggregate_status/1` returns `:failed` when any step failed
  - Tests: `aggregate_status/1` returns `:pending` when some steps pending and none failed
  - Tests: `aggregate_status/1` returns `:running` when no results yet
  - Tests: `severity_rank/1` orders statuses for sorting: failed > pending > skipped > passed
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/policies/status_policy.ex`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.10: ResultMatcher Policy

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/domain/policies/result_matcher_test.exs`
  - Tests: `match_pickle_to_feature/2` maps a Cucumber pickle (with uri + astNodeIds) back to a feature/scenario in the catalog
  - Tests: `match_test_step_to_pickle_step/3` maps a testStep (via testCase.testSteps[].pickleStepId) back to the pickle step
  - Tests: Returns `nil` when no match found
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/policies/result_matcher.ex`
  - Pure functions that take catalog data and Cucumber message IDs
  - Build lookup maps from pickle ID -> feature URI + scenario name
- [ ] ⏸ **REFACTOR**: Clean up

### 1.11: ProcessEnvelope Use Case

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/application/use_cases/process_envelope_test.exs`
  - Tests: `execute/2` with `%{"testRunStarted" => ...}` updates run status to `:running`
  - Tests: `execute/2` with `%{"pickle" => ...}` registers pickle in lookup index
  - Tests: `execute/2` with `%{"testCase" => ...}` registers testCase -> pickle mapping
  - Tests: `execute/2` with `%{"testCaseStarted" => ...}` creates a new TestCaseResult
  - Tests: `execute/2` with `%{"testStepFinished" => ...}` adds step result to the correct test case
  - Tests: `execute/2` with `%{"testCaseFinished" => ...}` finalizes the test case result
  - Tests: `execute/2` with `%{"testRunFinished" => ...}` updates run status to `:passed`/`:failed`
  - Tests: Uses dependency injection for `result_store` (mock GenServer)
  - Use `ExUnit.Case, async: true` with mocked store
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/application/use_cases/process_envelope.ex`
  - Pattern matches on envelope keys
  - Delegates to ResultStore for state updates
  - Broadcasts PubSub messages for real-time UI updates
- [ ] ⏸ **REFACTOR**: Clean up, extract envelope key matching into helpers

### 1.12: DiscoverFeatures Use Case

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/application/use_cases/discover_features_test.exs`
  - Tests: `execute/1` scans disk and parses all features, returning grouped catalog
  - Tests: Groups by app name (extracted from path)
  - Tests: Groups by adapter type (extracted from filename)
  - Tests: Handles empty results gracefully
  - Mock: `feature_file_scanner` and `gherkin_parser` via dependency injection
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/application/use_cases/discover_features.ex`
  - Calls scanner to find `.feature` files
  - Calls parser for each file
  - Uses AdapterClassifier to tag each feature
  - Returns `%{apps: %{"app_name" => [%Feature{}, ...]}, by_adapter: %{browser: [...], ...}}`
- [ ] ⏸ **REFACTOR**: Clean up

### 1.13: StartTestRun Use Case

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/application/use_cases/start_test_run_test.exs`
  - Tests: `execute/1` creates a TestRun, stores it, spawns executor, returns `{:ok, run_id}`
  - Tests: Scope can be `:app` (with app name), `:feature` (with feature URI), or `:scenario` (with scenario name + line)
  - Tests: Broadcasts `:test_run_started` via PubSub
  - Mock: `run_executor`, `result_store`, `pubsub`
  - Use `ExUnit.Case, async: true`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/application/use_cases/start_test_run.ex`
  - Creates TestRun entity
  - Stores in ResultStore
  - Resolves config path from app name
  - Builds tag/feature filter based on scope
  - Spawns RunExecutor (async, linked Task)
  - Broadcasts start event
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation
- [ ] ⏸ All domain tests pass with `async: true` (milliseconds, no I/O)
- [ ] ⏸ All application use case tests pass with mocks
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ `mix compile --warnings-as-errors` passes

---

## Phase 2: Infrastructure + Interface (phoenix-tdd)

### 2.1: Umbrella App Scaffold

- [ ] ⏸ Create new Phoenix app: `mix phx.new exo_dashboard --no-ecto --no-mailer --no-dashboard` in `apps/`
  - No Ecto (AD-1: in-memory only)
  - No mailer (dev tool)
  - No Phoenix dashboard (it IS the dashboard)
- [ ] ⏸ Configure `mix.exs`:
  - Add `boundary` dep and compiler
  - Add `jason` dep
  - Set `elixirc_paths` for test support
  - Configure `compilers: [:boundary, :phoenix_live_view] ++ Mix.compilers()`
- [ ] ⏸ Configure umbrella `config/config.exs`:
  - Add ExoDashboardWeb.Endpoint config with `pubsub_server: Jarga.PubSub`
- [ ] ⏸ Configure `config/dev.exs`:
  - Port 4010, code_reloader, watchers for esbuild + tailwind
- [ ] ⏸ Configure `config/test.exs`:
  - Port 4011, no watchers
- [ ] ⏸ Add esbuild + tailwind profiles in `config/config.exs`:
  - `exo_dashboard:` esbuild profile
  - `exo_dashboard:` tailwind profile
- [ ] ⏸ Set up `ExoDashboard.OTPApp` (application.ex):
  - Children: `ExoDashboardWeb.Telemetry`, `ExoDashboard.TestRuns.Infrastructure.ResultStore`, `ExoDashboardWeb.Endpoint`
- [ ] ⏸ Set up Boundary declarations:
  - `ExoDashboard.Features` -- deps: [], exports: domain entities
  - `ExoDashboard.TestRuns` -- deps: [ExoDashboard.Features], exports: domain entities
  - `ExoDashboardWeb` -- deps: [ExoDashboard.Features, ExoDashboard.TestRuns]
  - `ExoDashboard.OTPApp` -- top_level?, deps: [ExoDashboard.Features, ExoDashboard.TestRuns, ExoDashboardWeb]

### 2.2: Assets Setup (Tailwind 4 + daisyUI)

- [ ] ⏸ Create `apps/exo_dashboard/assets/` directory structure:
  - `css/app.css` -- Tailwind 4 imports with daisyUI plugin, heroicons plugin
  - `js/app.ts` -- Standard LiveView socket boilerplate (copy from identity)
  - `vendor/` -- Copy `daisyui.js`, `daisyui-theme.js`, `heroicons.js`, `topbar.cjs` from jarga_web
  - `package.json` -- Phoenix deps (phoenix, phoenix_html, phoenix_live_view)
- [ ] ⏸ Verify: `mix assets.build` compiles CSS and JS without errors

### 2.3: Gherkin Parser Node Script

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/infrastructure/gherkin_parser_test.exs`
  - Tests: `parse/1` with a valid `.feature` file path returns `{:ok, %Feature{}}` with correct name, scenarios, steps
  - Tests: `parse/1` with a feature containing Rules returns nested structure
  - Tests: `parse/1` with Scenario Outline + Examples returns expanded scenarios
  - Tests: `parse/1` with invalid file returns `{:error, reason}`
  - Tests: `parse/1` with non-existent file returns `{:error, :not_found}`
  - Use `ExoDashboard.DataCase` (or `ExUnit.Case` since no DB)
- [ ] ⏸ **GREEN**: Implement Gherkin parser in two parts:
  1. **Node script**: `apps/exo_dashboard/priv/gherkin_parser/parse.mjs`
     - Reads feature file paths from stdin (newline-separated)
     - Uses `@cucumber/gherkin` Parser, AstBuilder, GherkinClassicTokenMatcher
     - Outputs JSON to stdout: array of `{ uri, gherkinDocument }` objects
     - `package.json` with `@cucumber/gherkin` and `@cucumber/messages` deps
  2. **Elixir wrapper**: `apps/exo_dashboard/lib/exo_dashboard/features/infrastructure/gherkin_parser.ex`
     - Opens a Port to `node priv/gherkin_parser/parse.mjs`
     - Sends file paths, collects JSON output
     - Transforms JSON into `%Feature{}`, `%Scenario{}`, `%Step{}` structs
     - Handles port errors, timeouts
- [ ] ⏸ **REFACTOR**: Add caching (optional: cache parsed features by file mtime)

### 2.4: Feature File Scanner

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features/infrastructure/feature_file_scanner_test.exs`
  - Tests: `scan/0` returns list of paths matching `apps/*/test/features/**/*.feature`
  - Tests: `scan/1` with custom base path scans that directory
  - Tests: Results include the relative path from umbrella root
  - Use `ExUnit.Case, async: true` (reads disk but no DB)
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features/infrastructure/feature_file_scanner.ex`
  - Uses `Path.wildcard/1` to find feature files
  - Returns list of absolute paths
- [ ] ⏸ **REFACTOR**: Clean up

### 2.5: ResultStore (ETS-backed GenServer)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/result_store_test.exs`
  - Tests: `create_run/1` stores a TestRun and returns its id
  - Tests: `get_run/1` retrieves a stored run
  - Tests: `update_run/2` applies a function to mutate the stored run
  - Tests: `register_pickle/3` stores pickle_id -> {feature_uri, scenario_name} for a run
  - Tests: `register_test_case/3` stores testCase_id -> pickle_id mapping for a run
  - Tests: `add_test_case_result/3` adds/updates a TestCaseResult for a run
  - Tests: `get_test_case_results/1` returns all results for a run
  - Tests: `list_runs/0` returns all stored runs
  - Tests: Multiple concurrent runs are isolated
  - Use `ExUnit.Case, async: false` (shared GenServer state)
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/result_store.ex`
  - GenServer with ETS table for runs
  - Separate ETS tables for pickle index and test case index per run
  - API: `create_run/1`, `get_run/1`, `update_run/2`, `register_pickle/3`, `register_test_case/3`, `add_test_case_result/3`, `get_test_case_results/1`, `list_runs/0`
- [ ] ⏸ **REFACTOR**: Consider using `:ets.new` with `:named_table` for direct access

### 2.6: RunExecutor (Process Spawner)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/run_executor_test.exs`
  - Tests: `start/2` spawns a process that runs `bun run exo-bdd run` with correct args
  - Tests: `start/2` includes `--format message:<ndjson_path>` in args
  - Tests: `start/2` with app scope passes correct `--name` and optional `--adapter`
  - Tests: `start/2` with feature scope passes correct `--config` and feature path filter
  - Tests: Process exits normally on success (exit code 0)
  - Tests: Process reports failure on non-zero exit code
  - Use `ExUnit.Case, async: true` (mock System.cmd)
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/run_executor.ex`
  - `start(run_id, opts)` spawns a Task that:
    1. Determines config path from scope
    2. Creates temp NDJSON output path
    3. Builds bun command args (via `Mix.Tasks.ExoTest.build_cmd_args/5`)
    4. Spawns `System.cmd("bun", args, cd: exo_bdd_root, into: collector)`
    5. On completion, broadcasts `:run_process_exited` via PubSub
  - Supports cancellation via `Task.shutdown/2`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.7: NdjsonWatcher (File Tailer)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/ndjson_watcher_test.exs`
  - Tests: `start_link/1` begins watching a file path
  - Tests: When new lines are appended to the file, they are parsed as JSON and broadcast
  - Tests: Each parsed envelope is passed to `ProcessEnvelope.execute/2`
  - Tests: Watcher stops when file contains `testRunFinished` envelope
  - Tests: Watcher handles malformed JSON lines gracefully (logs warning, skips)
  - Use `ExUnit.Case, async: false` (file I/O + PubSub)
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/ndjson_watcher.ex`
  - GenServer that:
    1. Polls the NDJSON file at ~100ms intervals
    2. Tracks byte offset (reads only new content since last poll)
    3. Splits new content into lines, parses each as JSON
    4. Calls `ProcessEnvelope.execute/2` for each envelope
    5. Stops polling after `testRunFinished` or when the run process exits
- [ ] ⏸ **REFACTOR**: Consider using `:fs` or `FileSystem` for inotify-based watching instead of polling

### 2.8: Features Context Facade

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/features_test.exs`
  - Tests: `ExoDashboard.Features.discover/0` returns full catalog grouped by app and adapter
  - Tests: `ExoDashboard.Features.discover/1` with custom path scans that directory
  - Mock: parser and scanner via opts
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/features.ex`
  - Public API: `discover/0`, `discover/1`
  - Delegates to `DiscoverFeatures` use case
  - `use Boundary` config
- [ ] ⏸ **REFACTOR**: Clean up

### 2.9: TestRuns Context Facade

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/test_runs_test.exs`
  - Tests: `ExoDashboard.TestRuns.start_run/1` starts a new test run
  - Tests: `ExoDashboard.TestRuns.get_run/1` returns run state
  - Tests: `ExoDashboard.TestRuns.list_runs/0` returns all runs
  - Tests: `ExoDashboard.TestRuns.get_results/1` returns test case results for a run
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard/test_runs.ex`
  - Public API: `start_run/1`, `get_run/1`, `list_runs/0`, `get_results/1`
  - Delegates to use cases and ResultStore
  - `use Boundary` config
- [ ] ⏸ **REFACTOR**: Clean up

### 2.10: ExoDashboardWeb Module + Endpoint + Router

- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web.ex`
  - Follow IdentityWeb pattern: `:router`, `:live_view`, `:html`, `:verified_routes` macros
  - Boundary config: `deps: [ExoDashboard.Features, ExoDashboard.TestRuns]`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/endpoint.ex`
  - Standard Phoenix endpoint (no session sharing needed -- standalone dev tool)
  - LiveView socket at `/live`
  - Static file serving from `:exo_dashboard` priv
  - Code reloader in dev
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/router.ex`
  - Single browser pipeline (no auth)
  - Routes:
    ```elixir
    live_session :dashboard do
      live "/", DashboardLive, :index
      live "/features/:uri", FeatureDetailLive, :show
    end
    ```
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/components/layouts.ex`
  - Root layout: HTML skeleton with Tailwind CSS, app.js
  - App layout: Dashboard shell with sidebar/header
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/components/core_components.ex`
  - Copy relevant components from identity: `.button`, `.icon`, `.flash`, `.flash_group`
  - Add dashboard-specific base components

### 2.11: DashboardLive (Main View)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard_web/live/dashboard_live_test.exs`
  - Tests: `GET /` mounts DashboardLive and renders feature list
  - Tests: Features are grouped by app (shows app names as headings)
  - Tests: Each feature shows name, adapter badge, scenario count
  - Tests: Clicking "Run All" button for an app triggers `start_test_run` with app scope
  - Tests: Clicking "Run" on a single feature triggers `start_test_run` with feature scope
  - Tests: When a test run is in progress, a progress indicator appears
  - Tests: PubSub messages update results in real time (test via `send/2`)
  - Tests: Filter bar allows filtering by adapter type
  - Tests: Filter bar allows filtering by app name
  - Use `ExoDashboardWeb.ConnCase`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/live/dashboard_live.ex` + `.html.heex`
  - `mount/3`:
    - Call `ExoDashboard.Features.discover/0` to load catalog
    - Subscribe to `"exo_dashboard:results"` PubSub topic
    - Assign: features_by_app, active_filters, active_run, results
  - `handle_params/3`:
    - Apply filter params (?app=X&adapter=Y)
  - `handle_event/3`:
    - `"run_app"` -> `ExoDashboard.TestRuns.start_run(%{scope: :app, app: app})`
    - `"run_feature"` -> `ExoDashboard.TestRuns.start_run(%{scope: :feature, uri: uri})`
    - `"run_scenario"` -> `ExoDashboard.TestRuns.start_run(%{scope: :scenario, uri: uri, line: line})`
    - `"filter"` -> Update filter assigns, re-render
    - `"refresh"` -> Re-discover features from disk
  - `handle_info/2`:
    - `{:test_run_started, run_id}` -> Assign active run
    - `{:test_case_result_updated, result}` -> Update result in assigns
    - `{:test_run_finished, run_id, status}` -> Clear active run, update final results
  - Template: App-grouped feature tree with status badges, run buttons, progress bar
- [ ] ⏸ **REFACTOR**: Extract feature tree rendering into FeatureComponents

### 2.12: FeatureDetailLive (Single Feature View)

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard_web/live/feature_detail_live_test.exs`
  - Tests: `GET /features/:uri` renders the feature detail page
  - Tests: Shows feature name, description, tags
  - Tests: Lists all scenarios with their steps
  - Tests: Shows Rules as collapsible sections containing their scenarios
  - Tests: Each step shows keyword + text
  - Tests: "Run Feature" button triggers a test run scoped to this feature
  - Tests: "Run Scenario" button triggers a test run scoped to a single scenario
  - Tests: When results exist, each step shows pass/fail badge + duration
  - Tests: Failed steps show error message and stack trace
  - Tests: Results update in real time via PubSub
  - Use `ExoDashboardWeb.ConnCase`
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/live/feature_detail_live.ex` + `.html.heex`
  - `mount/3`:
    - Parse URI param, find feature in catalog
    - Subscribe to PubSub for results
    - Assign: feature, results, active_run
  - Renders: Feature header, scenario list, step detail with results overlay
- [ ] ⏸ **REFACTOR**: Extract step rendering into ResultComponents

### 2.13: Feature Components

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard_web/components/feature_components_test.exs`
  - Tests: `feature_card/1` renders feature name, adapter badge, scenario count
  - Tests: `scenario_row/1` renders scenario name, tag badges, status
  - Tests: `adapter_badge/1` renders colored badge for each adapter type
  - Tests: `app_group/1` renders app heading with feature list
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/components/feature_components.ex`
  - Function components: `feature_card/1`, `scenario_row/1`, `adapter_badge/1`, `app_group/1`, `feature_tree/1`
- [ ] ⏸ **REFACTOR**: Clean up

### 2.14: Result Components

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard_web/components/result_components_test.exs`
  - Tests: `status_badge/1` renders correct color/icon for each status
  - Tests: `step_result/1` renders step text + status + duration
  - Tests: `step_result/1` with failed status shows error message
  - Tests: `progress_bar/1` renders progress percentage
  - Tests: `run_summary/1` renders total/passed/failed/skipped counts
- [ ] ⏸ **GREEN**: Implement `apps/exo_dashboard/lib/exo_dashboard_web/components/result_components.ex`
  - Function components: `status_badge/1`, `step_result/1`, `progress_bar/1`, `run_summary/1`, `error_detail/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 2 Validation
- [ ] ⏸ All infrastructure tests pass
- [ ] ⏸ All interface tests pass
- [ ] ⏸ Phoenix app starts: `mix phx.server` on port 4010
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)
- [ ] ⏸ Pre-commit passes (`mix precommit`)

---

## Phase 3: Integration + Polish (phoenix-tdd)

### 3.1: End-to-End Integration Test

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/integration/full_flow_test.exs`
  - Tests: Discover features -> verify catalog has entries from real `.feature` files
  - Tests: Parse a known `.feature` file -> verify Feature entity matches expected structure
  - Tests: Gherkin parser handles all feature files in the umbrella without errors
- [ ] ⏸ **GREEN**: Fix any integration issues found
- [ ] ⏸ **REFACTOR**: Clean up

### 3.2: PubSub Real-Time Integration Test

- [ ] ⏸ **RED**: Write test `apps/exo_dashboard/test/exo_dashboard/integration/pubsub_streaming_test.exs`
  - Tests: NdjsonWatcher reads a fixture NDJSON file and broadcasts all envelopes
  - Tests: ProcessEnvelope correctly processes a full NDJSON stream fixture
  - Tests: ResultStore accumulates correct final state from a full stream
- [ ] ⏸ **GREEN**: Fix any issues
- [ ] ⏸ **REFACTOR**: Clean up

### 3.3: Allure Report Removal from exo-bdd

- [ ] ⏸ Remove `tools/exo-bdd/allure-report/` directory
- [ ] ⏸ Remove any allure-related dependencies from `tools/exo-bdd/package.json`
- [ ] ⏸ Verify `bun test` and `mix exo_test` still pass

### Phase 3 Validation
- [ ] ⏸ Full end-to-end feature discovery works against real `.feature` files
- [ ] ⏸ NDJSON streaming integration works with fixture files
- [ ] ⏸ All tests pass (`mix test`)
- [ ] ⏸ Pre-commit passes (`mix precommit`)
- [ ] ⏸ `mix boundary` clean

---

## Pre-Commit Checkpoint

Before creating the PR, run:
```bash
mix precommit
mix boundary
```

Ensure zero warnings, zero failures.

---

## Testing Strategy

### Test Distribution

| Layer | Count (est.) | Speed | Async? |
|-------|-------------|-------|--------|
| Domain entities (Phase 1) | ~8 | < 1ms each | Yes |
| Domain policies (Phase 1) | ~12 | < 1ms each | Yes |
| Application use cases (Phase 1) | ~15 | < 5ms each (mocked) | Yes |
| Infrastructure (Phase 2) | ~18 | < 100ms each | Mixed |
| LiveView interface (Phase 2) | ~20 | < 200ms each | No |
| Components (Phase 2) | ~12 | < 50ms each | Yes |
| Integration (Phase 3) | ~6 | < 2s each | No |
| **Total** | **~91** | | |

### Test Categories

- **Unit (async: true)**: All domain entities, policies, and mocked use cases
- **Infrastructure (async: mixed)**: GherkinParser (needs Node), ResultStore (shared GenServer), NdjsonWatcher (file I/O)
- **Interface (ConnCase)**: LiveView mount, render, events, PubSub messages
- **Integration**: End-to-end flows with real feature files and fixture NDJSON streams

### Test Fixtures

Create fixture files in `apps/exo_dashboard/test/support/fixtures/`:
- `simple.feature` -- minimal feature with 1 scenario, 3 steps
- `complex.feature` -- feature with Rules, Scenario Outlines, tags, Background
- `simple_run.ndjson` -- complete NDJSON stream for a passing test run
- `failed_run.ndjson` -- NDJSON stream with a failing scenario
- `partial_run.ndjson` -- incomplete NDJSON stream (for testing streaming)

### PubSub Topics

| Topic | Message | Description |
|-------|---------|-------------|
| `"exo_dashboard:runs"` | `{:test_run_started, run_id}` | New run created |
| `"exo_dashboard:runs"` | `{:test_run_finished, run_id, status}` | Run completed |
| `"exo_dashboard:run:<run_id>"` | `{:envelope, envelope_map}` | Raw envelope from NDJSON |
| `"exo_dashboard:run:<run_id>"` | `{:test_case_started, test_case_result}` | Test case began |
| `"exo_dashboard:run:<run_id>"` | `{:test_step_finished, test_step_result}` | Step completed |
| `"exo_dashboard:run:<run_id>"` | `{:test_case_finished, test_case_result}` | Test case completed |

---

## File Manifest

### New Files (Elixir)

```
apps/exo_dashboard/mix.exs
apps/exo_dashboard/lib/exo_dashboard.ex
apps/exo_dashboard/lib/exo_dashboard/application.ex
apps/exo_dashboard/lib/exo_dashboard/features.ex
apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/feature.ex
apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/scenario.ex
apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/step.ex
apps/exo_dashboard/lib/exo_dashboard/features/domain/entities/rule.ex
apps/exo_dashboard/lib/exo_dashboard/features/domain/policies/adapter_classifier.ex
apps/exo_dashboard/lib/exo_dashboard/features/application/use_cases/discover_features.ex
apps/exo_dashboard/lib/exo_dashboard/features/infrastructure/gherkin_parser.ex
apps/exo_dashboard/lib/exo_dashboard/features/infrastructure/feature_file_scanner.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_run.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_case_result.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/entities/test_step_result.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/policies/result_matcher.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/domain/policies/status_policy.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/application/use_cases/process_envelope.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/application/use_cases/start_test_run.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/result_store.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/run_executor.ex
apps/exo_dashboard/lib/exo_dashboard/test_runs/infrastructure/ndjson_watcher.ex
apps/exo_dashboard/lib/exo_dashboard_web.ex
apps/exo_dashboard/lib/exo_dashboard_web/endpoint.ex
apps/exo_dashboard/lib/exo_dashboard_web/router.ex
apps/exo_dashboard/lib/exo_dashboard_web/telemetry.ex
apps/exo_dashboard/lib/exo_dashboard_web/gettext.ex
apps/exo_dashboard/lib/exo_dashboard_web/components/layouts.ex
apps/exo_dashboard/lib/exo_dashboard_web/components/layouts/root.html.heex
apps/exo_dashboard/lib/exo_dashboard_web/components/layouts/app.html.heex
apps/exo_dashboard/lib/exo_dashboard_web/components/core_components.ex
apps/exo_dashboard/lib/exo_dashboard_web/components/feature_components.ex
apps/exo_dashboard/lib/exo_dashboard_web/components/result_components.ex
apps/exo_dashboard/lib/exo_dashboard_web/live/dashboard_live.ex
apps/exo_dashboard/lib/exo_dashboard_web/live/dashboard_live.html.heex
apps/exo_dashboard/lib/exo_dashboard_web/live/feature_detail_live.ex
apps/exo_dashboard/lib/exo_dashboard_web/live/feature_detail_live.html.heex
apps/exo_dashboard/priv/gherkin_parser/parse.mjs
apps/exo_dashboard/priv/gherkin_parser/package.json
apps/exo_dashboard/assets/css/app.css
apps/exo_dashboard/assets/js/app.ts
apps/exo_dashboard/assets/vendor/daisyui.js
apps/exo_dashboard/assets/vendor/daisyui-theme.js
apps/exo_dashboard/assets/vendor/heroicons.js
apps/exo_dashboard/assets/vendor/topbar.cjs
apps/exo_dashboard/assets/package.json
```

### New Test Files

```
apps/exo_dashboard/test/test_helper.exs
apps/exo_dashboard/test/support/conn_case.ex
apps/exo_dashboard/test/support/fixtures/simple.feature
apps/exo_dashboard/test/support/fixtures/complex.feature
apps/exo_dashboard/test/support/fixtures/simple_run.ndjson
apps/exo_dashboard/test/support/fixtures/failed_run.ndjson
apps/exo_dashboard/test/support/fixtures/partial_run.ndjson
apps/exo_dashboard/test/exo_dashboard/features/domain/entities/feature_test.exs
apps/exo_dashboard/test/exo_dashboard/features/domain/entities/scenario_test.exs
apps/exo_dashboard/test/exo_dashboard/features/domain/entities/step_test.exs
apps/exo_dashboard/test/exo_dashboard/features/domain/entities/rule_test.exs
apps/exo_dashboard/test/exo_dashboard/features/domain/policies/adapter_classifier_test.exs
apps/exo_dashboard/test/exo_dashboard/features/application/use_cases/discover_features_test.exs
apps/exo_dashboard/test/exo_dashboard/features/infrastructure/gherkin_parser_test.exs
apps/exo_dashboard/test/exo_dashboard/features/infrastructure/feature_file_scanner_test.exs
apps/exo_dashboard/test/exo_dashboard/features_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_run_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_case_result_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/domain/entities/test_step_result_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/domain/policies/status_policy_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/domain/policies/result_matcher_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/application/use_cases/process_envelope_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/application/use_cases/start_test_run_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/result_store_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/run_executor_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs/infrastructure/ndjson_watcher_test.exs
apps/exo_dashboard/test/exo_dashboard/test_runs_test.exs
apps/exo_dashboard/test/exo_dashboard_web/live/dashboard_live_test.exs
apps/exo_dashboard/test/exo_dashboard_web/live/feature_detail_live_test.exs
apps/exo_dashboard/test/exo_dashboard_web/components/feature_components_test.exs
apps/exo_dashboard/test/exo_dashboard_web/components/result_components_test.exs
apps/exo_dashboard/test/exo_dashboard/integration/full_flow_test.exs
apps/exo_dashboard/test/exo_dashboard/integration/pubsub_streaming_test.exs
```

### Modified Files (TypeScript -- exo-bdd)

```
tools/exo-bdd/src/application/config/ConfigSchema.ts  (add ReportConfig)
tools/exo-bdd/src/cli/run.ts                          (update buildCucumberArgs, runTests)
```

### Modified Files (Elixir -- perme8_tools)

```
apps/perme8_tools/lib/mix/tasks/exo_test.ex            (add message_output support)
```

### Modified Files (Umbrella Config)

```
config/config.exs   (add ExoDashboardWeb.Endpoint, esbuild, tailwind profiles)
config/dev.exs      (add ExoDashboardWeb.Endpoint dev config, port 4010)
config/test.exs     (add ExoDashboardWeb.Endpoint test config, port 4011)
```

### Removed Files (Phase 3.3)

```
tools/exo-bdd/allure-report/   (entire directory)
```

---

## Umbrella App Table Update

After completion, update `docs/umbrella_apps.md`:

| App | Type | Port (dev / test) | Description |
|-----|------|-------------------|-------------|
| `exo_dashboard` | Phoenix (dev tool) | 4010 / 4011 | BDD feature dashboard -- browse features, trigger runs, view results in real time |
