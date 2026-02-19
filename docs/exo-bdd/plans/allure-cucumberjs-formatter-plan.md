# Feature: Add allure-cucumberjs Formatter to exo-bdd

**Ticket**: #161
**Tool**: `tools/exo-bdd` (TypeScript, Bun runtime, `bun:test`)
**Subagent**: typescript-tdd

## Overview

Add Allure test reporting to exo-bdd by integrating the `allure-cucumberjs` formatter. Users can enable Allure reporting via config (`report.allure`) or CLI (`--allure`). When enabled, `buildCucumberArgs()` injects `--format allure-cucumberjs/reporter` and optional `--format-options` into the cucumber-js invocation, producing Allure result files for later report generation.

## UI Strategy

- **LiveView coverage**: N/A — this is a CLI tool, not a web app
- **TypeScript needed**: 100% — this is a TypeScript-only feature in `tools/exo-bdd`

## Affected Boundaries

- **Primary context**: `tools/exo-bdd` (standalone TypeScript tool, not an umbrella app)
- **Dependencies**: None — self-contained within `tools/exo-bdd`
- **Exported schemas**: `ExoBddConfig` (updated with `report` field)
- **New context needed?**: No — this extends the existing CLI runner

## Architecture Impact Analysis

### Files Modified

| File | Layer | Change |
|------|-------|--------|
| `tools/exo-bdd/package.json` | Infrastructure | Add `allure-cucumberjs` + `allure-js-commons` deps |
| `tools/exo-bdd/src/application/config/ConfigSchema.ts` | Application | Add `ReportConfig` type + `report` field to `ExoBddConfig` |
| `tools/exo-bdd/src/application/config/index.ts` | Application | Re-export new `ReportConfig` type |
| `tools/exo-bdd/src/cli/run.ts` | Interface/CLI | Add `--allure` to `parseRunArgs()`, update `buildCucumberArgs()` signature, wire in `runTests()` |

### Test Files Modified

| File | Layer | Change |
|------|-------|--------|
| `tools/exo-bdd/tests/application/config-schema.test.ts` | Application | Add tests for `report` field on `ExoBddConfig` |
| `tools/exo-bdd/tests/cli/run.test.ts` | Interface/CLI | Add tests for `--allure` flag parsing, `buildCucumberArgs` Allure injection |

### Key Design Decisions

1. **`buildCucumberArgs` stays pure** — It already takes an options object and returns a string array. We add an optional `allure` parameter (the resolved report config) rather than passing the full `ExoBddConfig`.

2. **Config type is `boolean | { resultsDir?: string }`** — Matches the ticket spec. `true` enables Allure with defaults; an object enables Allure with overrides.

3. **`--allure` CLI flag is sugar** — It sets `allure: true` in the resolved config. Config file takes precedence for `resultsDir` if both are specified.

4. **`--format-options` merging** — The allure `resultsDir` is passed as `--format-options '{"resultsDir":"<path>"}'`. This is a separate arg from any passthrough `--format-options` the user might supply. We inject it only when `resultsDir` is explicitly configured (not for the default).

5. **Allure format arg placement** — Injected before passthrough args so user-supplied `--format` flags don't conflict.

---

## Phase 1: Config Schema (typescript-tdd)

### Step 1.1: Add `report` field to `ExoBddConfig`

- ⏸ **RED**: Add tests to `tools/exo-bdd/tests/application/config-schema.test.ts`
  - Test: `ExoBddConfig with report.allure as true`
    - Create config with `report: { allure: true }`, assert `config.report?.allure` is `true`
  - Test: `ExoBddConfig with report.allure as object with resultsDir`
    - Create config with `report: { allure: { resultsDir: 'custom-results' } }`, assert `resultsDir` is `'custom-results'`
  - Test: `ExoBddConfig with report omitted (optional)`
    - Create config with just `adapters: {}`, assert `config.report` is `undefined`
  - Test: `ExoBddConfig with report.allure as false`
    - Create config with `report: { allure: false }`, assert `config.report?.allure` is `false`
  - Test: `ExoBddConfig with empty report object`
    - Create config with `report: {}`, assert `config.report?.allure` is `undefined`

- ⏸ **GREEN**: Update `tools/exo-bdd/src/application/config/ConfigSchema.ts`
  - Add `AllureReportConfig` type:
    ```typescript
    export type AllureReportConfig = boolean | {
      resultsDir?: string
    }
    ```
  - Add `ReportConfig` interface:
    ```typescript
    export interface ReportConfig {
      allure?: AllureReportConfig
    }
    ```
  - Add optional `report` field to `ExoBddConfig`:
    ```typescript
    report?: ReportConfig
    ```

- ⏸ **REFACTOR**: Ensure `ReportConfig` and `AllureReportConfig` are exported from `tools/exo-bdd/src/application/config/index.ts`

### Phase 1 Validation

- ⏸ All config schema tests pass (`bun test tests/application/config-schema.test.ts`)
- ⏸ Existing tests unaffected (`bun test`)

---

## Phase 2: CLI Arg Parsing — `--allure` flag (typescript-tdd)

### Step 2.1: Add `allure` field to `RunOptions` and parse `--allure`

- ⏸ **RED**: Add tests to `tools/exo-bdd/tests/cli/run.test.ts` in the `parseRunArgs` describe block
  - Test: `parses --allure flag`
    - `parseRunArgs(['--config', 'config.ts', '--allure'])` → `opts.allure` is `true`
  - Test: `allure defaults to false when not provided`
    - `parseRunArgs(['--config', 'config.ts'])` → `opts.allure` is `false`
  - Test: `parses --allure with other flags`
    - `parseRunArgs(['-c', 'config.ts', '-t', '@smoke', '--allure', '-a', 'http'])` → `opts.allure` is `true`, other fields correct, passthrough is empty
  - Test: `--allure does not appear in passthrough`
    - `parseRunArgs(['--config', 'config.ts', '--allure', '--format', 'progress'])` → passthrough is `['--format', 'progress']`, `opts.allure` is `true`

- ⏸ **GREEN**: Update `tools/exo-bdd/src/cli/run.ts`
  - Add `allure: boolean` to `RunOptions` interface
  - Initialize `let allure = false` in `parseRunArgs()`
  - Add `else if (arg === '--allure') { allure = true }` in the arg parsing loop
  - Return `allure` in the result object

- ⏸ **REFACTOR**: Clean up — ensure the new field is adjacent to similar boolean flags (`noRetry`)

### Phase 2 Validation

- ⏸ All `parseRunArgs` tests pass (`bun test tests/cli/run.test.ts`)
- ⏸ Existing tests unaffected

---

## Phase 3: buildCucumberArgs — Allure Format Injection (typescript-tdd)

### Step 3.1: Inject `--format allure-cucumberjs/reporter` when Allure is enabled

- ⏸ **RED**: Add tests to `tools/exo-bdd/tests/cli/run.test.ts` in the `buildCucumberArgs` describe block
  - Test: `includes --format allure-cucumberjs/reporter when allure is true`
    - Call `buildCucumberArgs({ ...baseOptions, features: './f/*.feature', allure: true })` → args contain `'--format'` followed by `'allure-cucumberjs/reporter'`
  - Test: `includes --format allure-cucumberjs/reporter when allure is object`
    - Call with `allure: {}` → args contain the `--format` pair
  - Test: `includes --format allure-cucumberjs/reporter when allure object has resultsDir`
    - Call with `allure: { resultsDir: 'custom-dir' }` → args contain the `--format` pair
  - Test: `does not include --format allure-cucumberjs/reporter when allure is false`
    - Call with `allure: false` → args do NOT contain `'allure-cucumberjs/reporter'`
  - Test: `does not include --format allure-cucumberjs/reporter when allure is undefined`
    - Call without `allure` param → args do NOT contain `'allure-cucumberjs/reporter'`
  - Test: `includes --format-options with resultsDir when configured`
    - Call with `allure: { resultsDir: 'my-results' }` → args contain `'--format-options'` followed by `'{"resultsDir":"my-results"}'`
  - Test: `does not include --format-options when allure is true (boolean)`
    - Call with `allure: true` → args do NOT contain `'--format-options'`
  - Test: `does not include --format-options when allure object has no resultsDir`
    - Call with `allure: {}` → args do NOT contain `'--format-options'`
  - Test: `allure format args come before passthrough args`
    - Call with `allure: { resultsDir: 'r' }, passthrough: ['--format', 'progress']` → index of `'allure-cucumberjs/reporter'` is less than index of `'progress'`
  - Test: `allure format args do not interfere with existing passthrough --format`
    - Call with `allure: true, passthrough: ['--format', 'progress']` → args contain BOTH `'allure-cucumberjs/reporter'` AND `'progress'`

- ⏸ **GREEN**: Update `buildCucumberArgs()` in `tools/exo-bdd/src/cli/run.ts`
  - Add optional `allure?: boolean | { resultsDir?: string }` to the options parameter type
  - After the `noRetry` block and before `args.push(...passthrough)`, add:
    ```typescript
    // Inject Allure formatter when enabled
    if (allure && allure !== false) {
      args.push('--format', 'allure-cucumberjs/reporter')
      if (typeof allure === 'object' && allure.resultsDir) {
        args.push('--format-options', JSON.stringify({ resultsDir: allure.resultsDir }))
      }
    }
    ```
  - Destructure `allure` from options

- ⏸ **REFACTOR**: Extract Allure-specific arg building into a clearly commented block

### Phase 3 Validation

- ⏸ All `buildCucumberArgs` tests pass
- ⏸ Existing `buildCucumberArgs` tests still pass (no Allure args leak into existing tests)

---

## Phase 4: Wire Config + CLI Flag into runTests() (typescript-tdd)

### Step 4.1: Resolve Allure config in `runTests()`

- ⏸ **RED**: This step has no new unit tests because `runTests()` spawns a real process and is tested via integration tests. The wiring correctness is verified by:
  1. The existing unit tests for `parseRunArgs` (Phase 2) — ensuring `--allure` is parsed
  2. The existing unit tests for `buildCucumberArgs` (Phase 3) — ensuring allure config produces correct args
  3. Manual/integration verification that the wiring connects the two

- ⏸ **GREEN**: Update `runTests()` in `tools/exo-bdd/src/cli/run.ts`
  - After loading config and before calling `buildCucumberArgs()`, resolve the effective allure config:
    ```typescript
    // Resolve Allure reporting config: CLI --allure flag OR config.report.allure
    const allureConfig = options.allure
      ? (config.report?.allure || true)
      : config.report?.allure
    const effectiveAllure = allureConfig && allureConfig !== false
      ? allureConfig
      : undefined
    ```
  - Pass `allure: effectiveAllure` to the `buildCucumberArgs()` call:
    ```typescript
    const cucumberArgs = buildCucumberArgs({
      features,
      configDir,
      setupPath,
      stepsImport,
      passthrough: options.passthrough,
      tags: effectiveTags,
      noRetry: options.noRetry,
      allure: effectiveAllure,
    })
    ```

- ⏸ **REFACTOR**: Extract allure resolution logic into a small helper function `resolveAllureConfig(cliAllure: boolean, configAllure?: AllureReportConfig)` if the inline logic is too noisy. Keep it in `run.ts` — it's a CLI concern.

### Phase 4 Validation

- ⏸ Full test suite passes (`bun test` from `tools/exo-bdd/`)
- ⏸ No regressions in any existing test file

---

## Phase 5: Package Dependencies (infrastructure)

### Step 5.1: Add allure packages to package.json

- ⏸ **ACTION**: Update `tools/exo-bdd/package.json`
  - Add to `dependencies`:
    ```json
    "allure-cucumberjs": "^3.0.0",
    "allure-js-commons": "^3.0.0"
    ```
  - Run `bun install` from `tools/exo-bdd/` to resolve and lock

- ⏸ **VERIFY**: Run `bun test` to confirm all tests still pass with new deps installed
- ⏸ **VERIFY**: Run `bun run -e "import('allure-cucumberjs/reporter')"` to confirm the module resolves

### Phase 5 Validation

- ⏸ `bun install` succeeds without resolution errors
- ⏸ `bun test` passes (no breaking dep conflicts)
- ⏸ `allure-cucumberjs/reporter` is importable

---

## Pre-Commit Checkpoint

- ⏸ Full test suite passes: `bun test` from `tools/exo-bdd/`
- ⏸ No TypeScript errors: `bunx tsc --noEmit` from `tools/exo-bdd/`
- ⏸ Commit contains:
  - Updated `package.json` with new deps
  - Updated `ConfigSchema.ts` with `report` field
  - Updated `config/index.ts` with new type exports
  - Updated `run.ts` with `--allure` parsing, `buildCucumberArgs` allure injection, `runTests` wiring
  - Updated `config-schema.test.ts` with report config tests
  - Updated `run.test.ts` with allure CLI + args tests

---

## Testing Strategy

| Layer | Test Count | File |
|-------|------------|------|
| Application (Config Schema) | 5 | `tests/application/config-schema.test.ts` |
| CLI (parseRunArgs) | 4 | `tests/cli/run.test.ts` |
| CLI (buildCucumberArgs) | 10 | `tests/cli/run.test.ts` |
| **Total new tests** | **19** | |

### Test Distribution

- **Pure function tests** (buildCucumberArgs): 10 — fast, no I/O, no mocks
- **Arg parsing tests** (parseRunArgs): 4 — fast, no I/O, no mocks
- **Type validation tests** (ConfigSchema): 5 — compile-time + runtime shape checks

### What's NOT unit tested (by design)

- `runTests()` wiring — This spawns a subprocess. Correctness is verified by the composition of the two unit-tested functions (`parseRunArgs` + `buildCucumberArgs`). Integration testing (manual or CI) covers the end-to-end flow.
- Actual Allure report generation — This is `allure-cucumberjs`'s responsibility. We test that we pass the correct args; the formatter itself is a third-party concern.

---

## Implementation Order Summary

```
Phase 1: ConfigSchema.ts + config-schema.test.ts  (types first)
Phase 2: run.ts parseRunArgs + run.test.ts         (CLI parsing)
Phase 3: run.ts buildCucumberArgs + run.test.ts    (arg building)
Phase 4: run.ts runTests wiring                     (glue code)
Phase 5: package.json + bun install                 (deps last — avoids blockers)
```

Dependencies are installed last because all unit tests operate on pure functions that don't import `allure-cucumberjs`. The `--format allure-cucumberjs/reporter` string is just a string literal in tests. This lets us do full TDD without waiting for package resolution.

## Acceptance Criteria Mapping

| Criteria | Covered By |
|----------|------------|
| `--allure` CLI flag produces allure-results/ | Phase 2 (parsing) + Phase 3 (arg injection) + Phase 4 (wiring) |
| `report.allure: true` in config produces same result | Phase 3 (buildCucumberArgs with `allure: true`) + Phase 4 (config resolution) |
| `report.allure: { resultsDir: 'custom-dir' }` writes to specified dir | Phase 3 (`--format-options` test) + Phase 4 (wiring) |
| Existing behavior unchanged when neither flag nor config set | Phase 3 (undefined/false tests) + Phase 2 (default false) |
| All new code has unit test coverage | 19 new tests across all modified functions |
