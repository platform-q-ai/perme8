# Feature: Smart App Boot Configuration and Selective Test Execution

**Ticket**: #416
**Status**: ⏸ Not Started

## Overview

Create a `mix affected_apps` task that calculates which umbrella apps are affected by a set
of changed files, using an automatically-derived dependency graph from each app's `mix.exs`
declarations. This replaces the inline Python selective matrix in CI with an authoritative
Elixir-native implementation that supports transitive dependency propagation, domain-to-surface
exo-bdd mapping, and machine-readable JSON output.

## UI Strategy

- **LiveView coverage**: N/A (dev tool, no UI)
- **TypeScript needed**: None

## App Ownership

- **Owning app**: `perme8_tools`
- **Repo**: None (dev tool, no database)
- **Migrations**: None
- **Feature files**: None (pure unit tests only)
- **Primary context**: `Perme8Tools.AffectedApps` (module namespace under perme8_tools)
- **Dependencies**: None (reads other apps' `mix.exs` files at runtime, no in_umbrella deps)
- **Exported schemas**: None
- **New context needed?**: No -- this is a flat module structure under `Perme8Tools`, not a
  bounded domain context. Mix tasks in `perme8_tools` follow a utility module pattern.

## Affected Boundaries

All code lives in `apps/perme8_tools/`:

| Artifact | Path |
|----------|------|
| Library modules | `apps/perme8_tools/lib/perme8_tools/affected_apps/` |
| Mix task | `apps/perme8_tools/lib/mix/tasks/affected_apps.ex` |
| Tests | `apps/perme8_tools/test/perme8_tools/affected_apps/` |
| Mix task test | `apps/perme8_tools/test/mix/tasks/affected_apps_test.exs` |

## Architecture

This is a **dev tool** with no database, no domain events, no LiveView. The standard Clean
Architecture layers (Domain/Application/Infrastructure) are not applicable. Instead, the
implementation follows the existing `perme8_tools` pattern: pure library modules with a
Mix task interface.

### Module Decomposition

```
lib/perme8_tools/affected_apps/
├── dependency_graph.ex     # Builds directed graph from mix.exs files
├── mix_exs_parser.ex       # Parses mix.exs files to extract in_umbrella deps
├── file_classifier.ex      # Maps changed file paths to owning apps + categories
├── affected_calculator.ex  # Computes affected app set with transitive propagation
├── exo_bdd_mapping.ex      # Maps affected apps to exo-bdd config+domain combos
└── test_paths.ex           # Generates unit test directory paths for affected apps

lib/mix/tasks/affected_apps.ex  # Mix.Tasks.AffectedApps - CLI interface
```

Each module is a pure functional module with no side effects (except I/O in the Mix task).
All file system access is injected or isolated to the Mix task layer.

### Data Flow

```
Changed files (CLI args / --diff / stdin)
    │
    ▼
FileClassifier.classify/2
    │  → [{app_name, :code | :test | :config | :non_code}, ...]
    │  → or :all_apps / :all_exo_bdd / :none
    ▼
AffectedCalculator.affected_apps/2
    │  uses DependencyGraph to propagate transitively
    │  → MapSet of affected app names
    ▼
┌───────────────────┬──────────────────────┐
│                   │                      │
▼                   ▼                      ▼
TestPaths           ExoBddMapping          JSON output
.unit_test_paths/2  .exo_bdd_combos/2      (--json flag)
```

---

## Phase 1: Core Library Modules (phoenix-tdd)

All modules in this phase are pure functions with no I/O. Tests use `ExUnit.Case, async: true`.

### Step 1.1: MixExsParser

Parses `mix.exs` file content (as a string) to extract `in_umbrella: true` dependency atoms.
Does NOT evaluate Elixir code -- uses regex or limited `Code.string_to_quoted` on the deps
block only.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/mix_exs_parser_test.exs`
  - Tests:
    - `parse_in_umbrella_deps/1` extracts `[:perme8_events, :identity]` from a string containing `{:perme8_events, in_umbrella: true}` and `{:identity, in_umbrella: true}` among other deps
    - Ignores non-umbrella deps (e.g., `{:jason, "~> 1.2"}`)
    - Ignores `in_umbrella: true` deps with `only: :test` (they are test-only, not compile deps) -- e.g., `{:jarga, in_umbrella: true, only: :test}` in `chat_web`
    - Returns empty list for mix.exs with no umbrella deps
    - Returns empty list for malformed/empty content
    - Handles multi-line dep declarations
    - Handles deps with extra options (e.g., `{:agents, in_umbrella: true, runtime: false}`)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/mix_exs_parser.ex`
  - Module: `Perme8Tools.AffectedApps.MixExsParser`
  - Public function: `parse_in_umbrella_deps(mix_exs_content :: String.t()) :: [atom()]`
  - Strategy: Use regex to find `{:app_name, in_umbrella: true}` patterns, excluding those with `only: :test`
- [ ] ⏸ **REFACTOR**: Clean up, add `@moduledoc`, `@doc`, typespecs

### Step 1.2: DependencyGraph

Builds a directed acyclic graph from app names and their dependencies. Provides
transitive closure queries (dependents of an app = all apps that directly or transitively
depend on it).

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/dependency_graph_test.exs`
  - Tests:
    - `build/1` creates a graph from a map of `%{app_name => [dep_atoms]}`
    - `direct_dependents/2` returns apps that directly depend on a given app
    - `transitive_dependents/2` returns all apps that directly or transitively depend on a given app
      - Example: changing `perme8_events` → includes `identity`, `agents`, `jarga`, `chat`, `notifications`, and all their transitive dependents (`jarga_web`, `agents_web`, etc.)
      - Example: changing `identity` → includes `agents`, `jarga`, `chat`, `notifications`, `agents_web`, `agents_api`, `jarga_web`, `jarga_api`, `webhooks`, `webhooks_api`, `entity_relationship_manager`, `chat_web`, `perme8_dashboard`
    - `all_apps/1` returns every app in the graph
    - A leaf app (e.g., `alkali`) with no dependents returns empty set for `transitive_dependents`
    - Handles self-referencing gracefully (ignored, not an error)
    - Detects circular dependencies and returns `{:error, :circular_dependency, cycle_path}`
    - `dependencies/2` returns the direct dependencies of a given app (the reverse: what does this app depend ON)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/dependency_graph.ex`
  - Module: `Perme8Tools.AffectedApps.DependencyGraph`
  - Struct: `%DependencyGraph{adjacency: %{atom => MapSet.t(atom)}, reverse: %{atom => MapSet.t(atom)}}`
    - `adjacency`: app → set of apps it depends on
    - `reverse`: app → set of apps that depend on it (i.e., dependents)
  - Public functions:
    - `build(deps_map :: %{atom => [atom]}) :: {:ok, t()} | {:error, :circular_dependency, [atom]}`
    - `direct_dependents(graph, app) :: MapSet.t(atom)`
    - `transitive_dependents(graph, app) :: MapSet.t(atom)` — BFS/DFS on the reverse adjacency
    - `all_apps(graph) :: MapSet.t(atom)`
    - `dependencies(graph, app) :: MapSet.t(atom)`
  - The graph is built once and queried multiple times (cheap to construct from the map)
- [ ] ⏸ **REFACTOR**: Clean up, ensure cycle detection uses Kahn's algorithm or DFS colouring

### Step 1.3: FileClassifier

Classifies changed file paths into their owning app and category. Handles shared config
files, tools/exo-bdd changes, non-code files, and app-specific files.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/file_classifier_test.exs`
  - Tests:
    - `classify/2` with app file `apps/identity/lib/identity/users.ex` → `{:app, :identity, :code}`
    - `classify/2` with test file `apps/agents/test/agents/sessions_test.exs` → `{:app, :agents, :test}`
    - `classify/2` with shared config `config/config.exs` → `:all_apps`
    - `classify/2` with root `mix.exs` → `:all_apps`
    - `classify/2` with `mix.lock` → `:all_apps`
    - `classify/2` with `.tool-versions` → `:all_apps`
    - `classify/2` with `.formatter.exs` → `:all_apps`
    - `classify/2` with `tools/exo-bdd/src/runner.ts` → `:all_exo_bdd`
    - `classify/2` with `docs/some-doc.md` → `:ignore`
    - `classify/2` with `scripts/deploy.sh` → `:ignore`
    - `classify/2` with `.github/workflows/ci.yml` → `:ignore`
    - `classify/2` with non-code file in app `apps/agents/README.md` → `:ignore` (non-code files within apps are not affected by default)
    - `classify/2` with unknown path → `:ignore`
    - `classify_all/2` aggregates a list of changed files into a result struct:
      - `%{affected_apps: MapSet.t(), all_apps?: boolean, all_exo_bdd?: boolean}`
    - Edge case: `apps/perme8_tools/lib/mix/tasks/affected_apps.ex` → `{:app, :perme8_tools, :code}`
    - Edge case: handles both forward-slash and OS-specific path separators
  - The second argument to `classify/2` is the list of known app names (atoms), so it can validate the app exists
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/file_classifier.ex`
  - Module: `Perme8Tools.AffectedApps.FileClassifier`
  - Public functions:
    - `classify(file_path :: String.t(), known_apps :: [atom]) :: classification()`
      - where classification is `{:app, atom, :code | :test} | :all_apps | :all_exo_bdd | :ignore`
    - `classify_all(file_paths :: [String.t()], known_apps :: [atom]) :: classification_result()`
      - Returns `%{directly_affected: MapSet.t(atom), all_apps?: boolean, all_exo_bdd?: boolean}`
  - Shared config patterns: `~r{^config/}`, `~r{^mix\.(exs|lock)$}`, `~r{^\.(tool-versions|formatter\.exs)$}`
  - Exo-bdd pattern: `~r{^tools/exo-bdd/}`
  - Ignore patterns: `~r{^docs/}`, `~r{^scripts/}`, `~r{^\.github/}`
  - App detection: `~r{^apps/([^/]+)/}` → extract app name, convert to atom with `String.to_existing_atom/1` or match against known list
  - Code file extensions: `.ex`, `.exs`, `.heex`, `.ts`, `.js`, `.cjs`, `.css`, `.json`, `.feature`, `.po`, `.pot`, `.svg`, `.png`
- [ ] ⏸ **REFACTOR**: Extract constants, ensure patterns match CI's path filter behaviour

### Step 1.4: AffectedCalculator

The core orchestrator: given classified files and a dependency graph, computes the full
set of affected apps with transitive propagation.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/affected_calculator_test.exs`
  - Tests use a fixture dependency graph matching the real Perme8 umbrella:
    ```
    perme8_events: []
    perme8_plugs: []
    identity: [:perme8_events, :perme8_plugs]
    agents: [:perme8_events, :perme8_plugs, :identity]
    notifications: [:perme8_events, :identity]
    chat: [:perme8_events, :identity, :agents]
    jarga: [:perme8_events, :identity, :agents, :notifications]
    entity_relationship_manager: [:perme8_events, :perme8_plugs, :jarga, :identity]
    webhooks: [:perme8_events, :identity, :jarga]
    jarga_web: [:perme8_events, :perme8_plugs, :jarga, :agents, :notifications, :chat, :chat_web]
    jarga_api: [:jarga, :identity, :perme8_plugs]
    agents_web: [:perme8_events, :agents, :identity, :jarga]
    agents_api: [:agents, :identity, :perme8_plugs]
    chat_web: [:chat, :identity, :agents]
    webhooks_api: [:webhooks, :identity, :jarga, :perme8_plugs]
    exo_dashboard: []
    perme8_dashboard: [:exo_dashboard, :agents_web, :identity, :jarga]
    alkali: []
    perme8_tools: []
    ```
  - Tests:
    - Changing a file in `identity` → includes `identity` + all transitive dependents
    - Changing a file in `alkali` → only `alkali`
    - Changing a file in `perme8_events` → all apps that depend on it (transitively = most apps)
    - Changing shared config → all apps
    - Empty file list → empty affected set
    - Changing a file in `jarga_web` → only `jarga_web` + `perme8_dashboard` (since perme8_dashboard depends on jarga transitively, not jarga_web directly, but agents_web depends on jarga)
    - Actually: `jarga_web` has no dependents in the graph → only `jarga_web` affected
    - Multiple files across apps → union of all affected sets
    - Non-code files → ignored, don't add apps
    - `tools/exo-bdd/` changes → sets `all_exo_bdd?` flag but no unit test apps
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/affected_calculator.ex`
  - Module: `Perme8Tools.AffectedApps.AffectedCalculator`
  - Public function:
    - `calculate(classification_result, graph) :: %{affected_apps: MapSet.t(atom), all_apps?: boolean, all_exo_bdd?: boolean}`
  - Logic:
    1. If `all_apps?` is true, return all apps from graph
    2. For each directly affected app, compute transitive dependents and union them
    3. Include the directly affected app itself
    4. Carry forward `all_exo_bdd?` flag
- [ ] ⏸ **REFACTOR**: Clean up, ensure the calculation is O(V+E) not O(V*E)

### Step 1.5: ExoBddMapping

Maps affected apps to exo-bdd config+domain combos using the same domain-to-surface
mapping as the CI Python script.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/exo_bdd_mapping_test.exs`
  - Tests:
    - `exo_bdd_combos/2` with affected `[:identity]` → `[%{app: "identity", domain: "browser", config_name: "identity", timeout: 15}, %{app: "identity", domain: "security", config_name: "identity", timeout: 20}]`
    - With affected `[:jarga]` → fan-out to `jarga-web`, `jarga-api`, `erm` combos (6 combos: jarga-web browser+security, jarga-api http+security, erm http+security)
    - With affected `[:webhooks]` → fan-out to `webhooks-api` combos
    - With affected `[:agents]` → `agents` combos (http+security) since agents has own exo-bdd
    - With affected `[:jarga_web]` → `jarga-web` combos (browser+security)
    - With affected `[:alkali]` → `alkali` cli combo
    - With `all_exo_bdd?: true` → all combos
    - With affected `[:perme8_tools]` → no exo-bdd combos (perme8_tools has no exo-bdd tests)
    - `all_combos/0` returns the full list matching CI ALL_COMBOS
    - Domain-to-surface fan-out mapping matches CI Python exactly
    - Apps with no exo-bdd combos → empty list for that app
    - Combo output includes `app`, `domain`, `config_name`, `timeout` fields
    - Deduplication: if both `jarga` and `jarga_web` are affected, `jarga-web` combos appear only once
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/exo_bdd_mapping.ex`
  - Module: `Perme8Tools.AffectedApps.ExoBddMapping`
  - Constants:
    - `@all_combos` — list of all combo maps matching CI ALL_COMBOS
    - `@fan_out` — domain-to-surface mapping: `%{jarga: ["jarga-web", "jarga-api", "erm"], webhooks: ["webhooks-api"]}` etc.
    - `@app_name_to_exo_app` — maps atom app names to hyphenated exo-bdd app names
  - Public functions:
    - `exo_bdd_combos(affected_apps :: MapSet.t(atom), opts :: keyword) :: [combo_map]`
      - `opts[:all_exo_bdd?]` → return all combos
    - `all_combos() :: [combo_map]`
  - Logic:
    1. For each affected app, look up its exo-bdd app name(s) via fan-out map
    2. Filter `@all_combos` by matched app names
    3. Deduplicate
- [ ] ⏸ **REFACTOR**: Extract fan-out mapping as a discoverable data structure

### Step 1.6: TestPaths

Generates unit test directory paths for the set of affected apps.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/test_paths_test.exs`
  - Tests:
    - `unit_test_paths/2` with affected `[:identity, :agents]` → `["apps/identity/test", "apps/agents/test"]`
    - With affected `[:jarga_web]` → `["apps/jarga_web/test"]`
    - With `all_apps?` true → `["apps/*/test"]` (wildcard for mix test)
    - Empty affected set → empty list
    - Handles `entity_relationship_manager` correctly (long dir name)
    - `mix_test_args/2` generates the full `mix test` argument list: `["--only", "test", "apps/identity/test", "apps/agents/test"]`
    - `mix_test_command/2` generates the full command string: `"mix test apps/identity/test apps/agents/test"`
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/test_paths.ex`
  - Module: `Perme8Tools.AffectedApps.TestPaths`
  - Public functions:
    - `unit_test_paths(affected_apps :: MapSet.t(atom), opts :: keyword) :: [String.t()]`
    - `mix_test_args(affected_apps, opts) :: [String.t()]`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 1 Validation

- [ ] ⏸ All library module tests pass with `async: true` (milliseconds, no I/O)
- [ ] ⏸ No boundary violations
- [ ] ⏸ All modules have `@moduledoc`, `@doc`, typespecs

---

## Phase 2: Integration — Graph Discovery + Mix Task (phoenix-tdd)

This phase connects the pure modules to the real file system and provides the CLI interface.

### Step 2.1: GraphDiscovery (Integration Helper)

Discovers all umbrella apps and builds the real dependency graph by reading mix.exs files
from disk. This is the only module that performs file I/O (besides the Mix task).

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/graph_discovery_test.exs`
  - Tests (these read real files, so NOT async):
    - `discover_apps/1` given the real umbrella root finds all 19 app directories
    - `build_graph/1` from real umbrella root produces a valid graph with all apps
    - The discovered graph matches known deps (e.g., `identity` depends on `perme8_events`, `perme8_plugs`)
    - `perme8_tools` has no in_umbrella deps in the discovered graph
    - `alkali` has no in_umbrella deps in the discovered graph
    - `perme8_events` has no in_umbrella deps
    - `jarga_web` depends on `jarga`, `agents`, `perme8_events`, `perme8_plugs`, `notifications`, `chat`, `chat_web`
    - No circular dependencies in the real graph
    - Edge case: apps dir contains only directories (not files)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/graph_discovery.ex`
  - Module: `Perme8Tools.AffectedApps.GraphDiscovery`
  - Public functions:
    - `discover_apps(umbrella_root :: String.t()) :: [atom]` — lists `apps/*/mix.exs`, extracts app names
    - `build_graph(umbrella_root :: String.t()) :: {:ok, DependencyGraph.t()} | {:error, term}`
      - For each app, reads `apps/{app}/mix.exs`, passes to MixExsParser, builds deps map, calls DependencyGraph.build/1
  - File I/O: `File.read!/1` for each mix.exs, `File.ls!/1` for apps directory
- [ ] ⏸ **REFACTOR**: Error handling for missing/unreadable mix.exs files

### Step 2.2: DiffProvider (Git Integration)

Provides the list of changed files from git diff or explicit args.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/diff_provider_test.exs`
  - Tests:
    - `from_args/1` with `["apps/identity/lib/identity.ex", "config/config.exs"]` → returns those paths
    - `from_args/1` with empty list → returns empty list
    - `from_git_diff/2` calls `git diff --name-only <base>...HEAD` (tested with mock/fixture)
    - `from_stdin/0` reads lines from stdin (tested with StringIO or similar mock)
    - Strips whitespace and empty lines from all sources
    - Validates paths are relative (no leading `/`)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/diff_provider.ex`
  - Module: `Perme8Tools.AffectedApps.DiffProvider`
  - Public functions:
    - `from_args(args :: [String.t()]) :: [String.t()]`
    - `from_git_diff(base_branch :: String.t(), opts :: keyword) :: {:ok, [String.t()]} | {:error, term}`
      - Calls `System.cmd("git", ["diff", "--name-only", "#{base}...HEAD"])`
      - Injectable: `opts[:system_cmd]` for testing
    - `from_stdin(opts :: keyword) :: [String.t()]`
      - Reads from `:stdio` or injected IO device
- [ ] ⏸ **REFACTOR**: Clean up error handling

### Step 2.3: OutputFormatter

Formats the results for human-readable or JSON output.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/perme8_tools/affected_apps/output_formatter_test.exs`
  - Tests:
    - `format_json/1` produces valid JSON with keys: `affected_apps`, `unit_test_paths`, `exo_bdd_combos`, `all_apps`, `all_exo_bdd`
    - `format_json/1` output is parseable by `Jason.decode!/1`
    - `format_json/1` sorts app names alphabetically for deterministic output
    - `format_human/1` produces readable text output with sections
    - `format_human/1` with no affected apps shows "No apps affected"
    - `format_human/1` with all apps shows "All apps affected (shared config change)"
    - JSON output `affected_apps` are strings (not atoms), sorted
    - JSON output `exo_bdd_combos` matches CI matrix format
    - JSON output `unit_test_paths` are string paths
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/perme8_tools/affected_apps/output_formatter.ex`
  - Module: `Perme8Tools.AffectedApps.OutputFormatter`
  - Public functions:
    - `format_json(result :: map) :: String.t()`
    - `format_human(result :: map) :: String.t()`
  - Uses `Jason.encode!/2` for JSON (already a dependency of perme8_tools)
- [ ] ⏸ **REFACTOR**: Clean up formatting

### Step 2.4: Mix.Tasks.AffectedApps

The CLI entry point. Parses args, orchestrates the pipeline, outputs results.

- [ ] ⏸ **RED**: Write test `apps/perme8_tools/test/mix/tasks/affected_apps_test.exs`
  - Tests:
    - Integration test: calling with real file paths against the real umbrella produces correct output
    - `run/1` with `["apps/identity/lib/identity.ex"]` includes `identity` and dependents in output
    - `run/1` with `["config/config.exs"]` outputs all apps
    - `run/1` with `["apps/alkali/lib/alkali.ex"]` outputs only `alkali`
    - `run/1` with `["--json", "apps/identity/lib/identity.ex"]` produces valid JSON output
    - `run/1` with `["--diff", "main"]` invokes git diff (may skip in CI if no git history)
    - `run/1` with `["apps/perme8_events/lib/perme8_events.ex"]` propagates to most apps
    - `run/1` with `["docs/README.md"]` outputs no affected apps
    - `run/1` with `["tools/exo-bdd/src/runner.ts"]` outputs all exo-bdd combos but no unit test paths
    - `run/1` with no args and no stdin raises with usage message
    - `run/1` with `["--json", "apps/jarga/lib/jarga.ex"]` includes fan-out exo-bdd combos for jarga-web, jarga-api, erm
    - Edge: `run/1` with multiple file args across different apps unions the results
    - Performance: `run/1` completes in under 2 seconds (timing assertion)
- [ ] ⏸ **GREEN**: Implement `apps/perme8_tools/lib/mix/tasks/affected_apps.ex`
  - Module: `Mix.Tasks.AffectedApps`
  - `@shortdoc "Computes affected umbrella apps from changed files"`
  - `use Mix.Task`
  - `use Boundary, top_level?: true`
  - Switches: `--json`, `--diff <branch>`, file args, stdin fallback
  - Pipeline:
    1. Parse args (OptionParser)
    2. Get changed files (from args, `--diff`, or stdin)
    3. Discover graph (`GraphDiscovery.build_graph/1`)
    4. Classify files (`FileClassifier.classify_all/2`)
    5. Calculate affected (`AffectedCalculator.calculate/2`)
    6. Generate test paths (`TestPaths.unit_test_paths/2`)
    7. Generate exo-bdd combos (`ExoBddMapping.exo_bdd_combos/2`)
    8. Format output (`OutputFormatter.format_json/1` or `format_human/1`)
    9. Print to stdout
- [ ] ⏸ **REFACTOR**: Add `@moduledoc` with usage examples, handle edge cases

### Phase 2 Validation

- [ ] ⏸ All integration tests pass
- [ ] ⏸ Mix task is callable as `mix affected_apps` from umbrella root
- [ ] ⏸ `--json` output is valid, parseable JSON
- [ ] ⏸ `--diff main` works when git history is available
- [ ] ⏸ Completes in under 2 seconds for the full umbrella
- [ ] ⏸ No boundary violations (`mix boundary`)
- [ ] ⏸ Full test suite passes (`mix test`)

---

## Phase 3: Edge Cases and Robustness (phoenix-tdd)

### Step 3.1: Non-Code File Filtering in FileClassifier

Ensure the classifier correctly identifies code vs non-code files within app directories.

- [ ] ⏸ **RED**: Add edge case tests to `file_classifier_test.exs`
  - Tests:
    - `apps/agents/README.md` → `:ignore`
    - `apps/agents/lib/agents/something.ex` → `{:app, :agents, :code}`
    - `apps/agents/test/agents/something_test.exs` → `{:app, :agents, :test}`
    - `apps/agents/priv/repo/migrations/123_create.exs` → `{:app, :agents, :code}` (migrations are code)
    - `apps/agents/assets/js/app.ts` → `{:app, :agents, :code}` (assets are code)
    - `apps/agents/.formatter.exs` → `{:app, :agents, :code}` (app-level formatter is code)
    - `.github/workflows/ci.yml` → `:ignore`
    - `.github/CODEOWNERS` → `:ignore`
    - Empty string → `:ignore`
- [ ] ⏸ **GREEN**: Update `FileClassifier` to handle these edge cases
- [ ] ⏸ **REFACTOR**: Document the code file extension list

### Step 3.2: Circular Dependency Detection

Ensure the graph builder reports circular dependencies clearly.

- [ ] ⏸ **RED**: Add circular dependency tests to `dependency_graph_test.exs`
  - Tests:
    - Graph with `a → b → c → a` returns `{:error, :circular_dependency, [:a, :b, :c]}`
    - Graph with `a → b → a` returns `{:error, :circular_dependency, [:a, :b]}`
    - Real umbrella graph has no circular dependencies (integration test)
- [ ] ⏸ **GREEN**: Ensure `DependencyGraph.build/1` includes topological sort validation
- [ ] ⏸ **REFACTOR**: Improve error message with cycle path

### Step 3.3: New App Auto-Discovery

Ensure newly added apps are automatically picked up without any manual graph maintenance.

- [ ] ⏸ **RED**: Add tests to `graph_discovery_test.exs`
  - Tests:
    - Discovery finds all apps by scanning `apps/` directory
    - App names are derived from directory names (converted to atoms)
    - Handles the `entity_relationship_manager` long name correctly
    - If a new directory appears under `apps/` with a valid `mix.exs`, it's included
- [ ] ⏸ **GREEN**: Verify `GraphDiscovery.discover_apps/1` handles this
- [ ] ⏸ **REFACTOR**: Clean up

### Step 3.4: Stdin Input Support

Support piping changed files via stdin for CI integration.

- [ ] ⏸ **RED**: Add stdin tests to `diff_provider_test.exs`
  - Tests:
    - Reads newline-separated file paths from stdin
    - Strips empty lines and whitespace
    - Works with `echo "file1\nfile2" | mix affected_apps`
- [ ] ⏸ **GREEN**: Implement stdin reading in `DiffProvider.from_stdin/1`
- [ ] ⏸ **REFACTOR**: Clean up

### Phase 3 Validation

- [ ] ⏸ All edge case tests pass
- [ ] ⏸ Circular dependency detection works
- [ ] ⏸ New apps auto-discovered
- [ ] ⏸ Stdin input works
- [ ] ⏸ Full test suite passes

---

## Phase 4: Dry-Run and CI Validation (phoenix-tdd)

### Step 4.1: Dry-Run Mode

A `--dry-run` flag that shows what would be executed without running tests.

- [ ] ⏸ **RED**: Add `--dry-run` tests to `affected_apps_test.exs`
  - Tests:
    - `run/1` with `["--dry-run", "apps/identity/lib/identity.ex"]` shows affected apps and test commands without executing
    - Dry-run output includes: affected apps list, `mix test` command, `mix exo_test` commands
    - Dry-run output is human-readable (not JSON unless `--json` also passed)
    - `--dry-run --json` produces JSON with a `commands` key listing the commands that would run
- [ ] ⏸ **GREEN**: Add `--dry-run` support to `Mix.Tasks.AffectedApps`
- [ ] ⏸ **REFACTOR**: Clean up

### Step 4.2: CI Validation — Check Against Python Matrix

A validation mode that compares the Elixir implementation output against the expected
CI selective matrix behaviour (useful during migration).

- [ ] ⏸ **RED**: Write test to validate parity with CI Python script logic
  - Tests in `apps/perme8_tools/test/perme8_tools/affected_apps/ci_parity_test.exs`:
    - Given `jarga` changed → exo-bdd combos include `jarga-web`, `jarga-api`, `erm` (matches Python `changed_apps()`)
    - Given `webhooks` changed → exo-bdd combos include `webhooks-api` (matches Python)
    - Given `agents` changed → exo-bdd combos include `agents` http+security (matches Python)
    - Given `identity` changed → exo-bdd combos include `identity` browser+security (matches Python)
    - Given shared config changed → all combos (matches Python `is_main or shared_changed`)
    - Given `tools/exo-bdd/` changed → all combos (matches Python `exo_bdd_changed`)
    - Given `exo_dashboard` changed → `exo-dashboard` combos (matches Python)
    - Given `perme8_dashboard` changed → `perme8-dashboard` combos (matches Python)
    - Transitive propagation: `identity` change → includes `agents-web`, `agents-api` etc. (EXCEEDS Python which only does direct file-path matching — document this as an improvement)
- [ ] ⏸ **GREEN**: Ensure all parity tests pass
- [ ] ⏸ **REFACTOR**: Document any intentional differences from Python implementation (transitive deps are an improvement)

### Phase 4 Validation

- [ ] ⏸ Dry-run mode works
- [ ] ⏸ CI parity tests pass
- [ ] ⏸ Differences from Python script are documented and intentional

---

## Pre-Commit Checkpoint

- [ ] ⏸ `mix compile --warnings-as-errors` passes
- [ ] ⏸ `mix format --check-formatted` passes
- [ ] ⏸ `mix boundary` passes (no violations)
- [ ] ⏸ `mix test` passes (all apps)
- [ ] ⏸ `mix precommit` passes
- [ ] ⏸ `mix affected_apps --json apps/identity/lib/identity.ex` produces correct output
- [ ] ⏸ `mix affected_apps --diff main` works (when on a branch)
- [ ] ⏸ Performance: full calculation completes in under 2 seconds

---

## Testing Strategy

### Test Distribution

| Layer | File | Tests | async? |
|-------|------|-------|--------|
| MixExsParser | `test/perme8_tools/affected_apps/mix_exs_parser_test.exs` | ~8 | yes |
| DependencyGraph | `test/perme8_tools/affected_apps/dependency_graph_test.exs` | ~10 | yes |
| FileClassifier | `test/perme8_tools/affected_apps/file_classifier_test.exs` | ~15 | yes |
| AffectedCalculator | `test/perme8_tools/affected_apps/affected_calculator_test.exs` | ~10 | yes |
| ExoBddMapping | `test/perme8_tools/affected_apps/exo_bdd_mapping_test.exs` | ~12 | yes |
| TestPaths | `test/perme8_tools/affected_apps/test_paths_test.exs` | ~6 | yes |
| GraphDiscovery | `test/perme8_tools/affected_apps/graph_discovery_test.exs` | ~8 | no (file I/O) |
| DiffProvider | `test/perme8_tools/affected_apps/diff_provider_test.exs` | ~6 | yes (mocked) |
| OutputFormatter | `test/perme8_tools/affected_apps/output_formatter_test.exs` | ~8 | yes |
| Mix.Tasks.AffectedApps | `test/mix/tasks/affected_apps_test.exs` | ~12 | no (integration) |
| CI Parity | `test/perme8_tools/affected_apps/ci_parity_test.exs` | ~10 | yes |

**Total estimated tests: ~105**

### Test Principles

- All pure module tests are `async: true` — no file I/O, no shell commands
- `GraphDiscovery` tests read real `mix.exs` files (integration) — NOT async
- Mix task tests are integration tests that run the real pipeline — NOT async
- CI parity tests use fixture data, NOT real file I/O — `async: true`
- All tests use `ExUnit.Case` (not `DataCase` — no database involved)
- Test file structure mirrors source: `test/perme8_tools/affected_apps/` for library modules, `test/mix/tasks/` for mix tasks

### Key Test Fixtures

A shared fixture module or test helper providing the canonical Perme8 dependency map:

```elixir
# test/support/affected_apps_fixtures.ex or inline in tests
@perme8_deps %{
  perme8_events: [],
  perme8_plugs: [],
  identity: [:perme8_events, :perme8_plugs],
  agents: [:perme8_events, :perme8_plugs, :identity],
  notifications: [:perme8_events, :identity],
  chat: [:perme8_events, :identity, :agents],
  jarga: [:perme8_events, :identity, :agents, :notifications],
  entity_relationship_manager: [:perme8_events, :perme8_plugs, :jarga, :identity],
  webhooks: [:perme8_events, :identity, :jarga],
  jarga_web: [:perme8_events, :perme8_plugs, :jarga, :agents, :notifications, :chat, :chat_web],
  jarga_api: [:jarga, :identity, :perme8_plugs],
  agents_web: [:perme8_events, :agents, :identity, :jarga],
  agents_api: [:agents, :identity, :perme8_plugs],
  chat_web: [:chat, :identity, :agents],
  webhooks_api: [:webhooks, :identity, :jarga, :perme8_plugs],
  exo_dashboard: [],
  perme8_dashboard: [:exo_dashboard, :agents_web, :identity, :jarga],
  alkali: [],
  perme8_tools: []
}
```

---

## Appendix A: Full Dependency Graph (from mix.exs analysis)

Derived from reading all `mix.exs` files during research:

| App | in_umbrella deps |
|-----|-----------------|
| `perme8_events` | (none) |
| `perme8_plugs` | (none) |
| `identity` | `perme8_events`, `perme8_plugs` |
| `agents` | `perme8_events`, `perme8_plugs`, `identity` |
| `notifications` | `perme8_events`, `identity` |
| `chat` | `perme8_events`, `identity`, `agents` |
| `jarga` | `perme8_events`, `identity`, `agents`, `notifications` |
| `entity_relationship_manager` | `perme8_events`, `perme8_plugs`, `jarga`, `identity` |
| `webhooks` | `perme8_events`, `identity`, `jarga` |
| `jarga_web` | `perme8_events`, `perme8_plugs`, `jarga`, `agents`, `notifications`, `chat`, `chat_web` |
| `jarga_api` | `jarga`, `identity`, `perme8_plugs` |
| `agents_web` | `perme8_events`, `agents`, `identity`, `jarga` |
| `agents_api` | `agents`, `identity`, `perme8_plugs` |
| `chat_web` | `chat`, `identity`, `agents` (runtime); `jarga`, `notifications` (test-only, excluded) |
| `webhooks_api` | `webhooks`, `identity`, `jarga`, `perme8_plugs` |
| `exo_dashboard` | (none) |
| `perme8_dashboard` | `exo_dashboard`, `agents_web`, `identity`, `jarga` |
| `alkali` | (none) |
| `perme8_tools` | (none) |

## Appendix B: Exo-BDD Domain-to-Surface Fan-Out Mapping

Domain apps without their own exo-bdd configs fan out to their surface apps:

| Domain App (atom) | Exo-BDD Surface Apps | Rationale |
|-------------------|---------------------|-----------|
| `jarga` | `jarga-web`, `jarga-api`, `erm` | jarga has no own exo-bdd; changes affect its web, API, and ERM consumers |
| `webhooks` | `webhooks-api` | webhooks has no own exo-bdd; only tested via its API |
| `chat` | (none currently) | chat has no exo-bdd config yet |
| `chat_web` | (none currently) | chat_web has no exo-bdd config yet |
| `notifications` | (none currently) | notifications has no exo-bdd config yet |
| `perme8_events` | (propagates transitively) | foundational; transitively affects all dependent apps |
| `perme8_plugs` | (propagates transitively) | foundational; transitively affects all dependent apps |

Apps WITH their own exo-bdd configs (direct mapping):

| App (atom) | Exo-BDD App Name | Domains |
|------------|-----------------|---------|
| `agents` | `agents` | http, security |
| `agents_api` | `agents-api` | http, security |
| `agents_web` | `agents-web` | browser, security |
| `alkali` | `alkali` | cli |
| `entity_relationship_manager` | `erm` | http, security |
| `identity` | `identity` | browser, security |
| `jarga_api` | `jarga-api` | http, security |
| `jarga_web` | `jarga-web` | browser, security |
| `exo_dashboard` | `exo-dashboard` | browser |
| `perme8_dashboard` | `perme8-dashboard` | browser, security |
| `webhooks_api` | `webhooks-api` | http, security |

## Appendix C: Shared Config File Patterns

Files that trigger ALL apps when changed:

```
config/                    # Any file under config/
mix.exs                    # Root mix.exs
mix.lock                   # Dependency lock file
.tool-versions             # Erlang/Elixir version
.formatter.exs             # Root formatter config
```

Files that are always ignored:

```
docs/                      # Documentation (no tests)
scripts/                   # Build/deploy scripts (no tests)
.github/                   # CI workflows, CODEOWNERS (no tests)
```

Special case:

```
tools/exo-bdd/             # Exo-BDD framework changes → all exo-bdd tests, NOT unit tests
```
