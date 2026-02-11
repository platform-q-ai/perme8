# Integration Test Plan

## Overview

Integration tests that validate the `exo-bdd` framework end-to-end by:
1. Running `.feature` files through `cucumber-js` against preconfigured test projects
2. Test projects use the framework's own CLI adapter and step definitions
3. An outer `bun test` harness spawns the project runner and asserts on stdout/exit code
4. A `test:project` script in `package.json` accepts a project name and forwards all additional arguments to `cucumber-js`

## Directory Structure

```
integration/
├── projects/
│   └── cli/
│       ├── exo-bdd.config.ts          # defineConfig() with cli adapter only
│       ├── cucumber.yml                  # cucumber-js profile for this project
│       ├── features/
│       │   ├── cli-execution.feature     # Command execution scenarios
│       │   ├── cli-environment.feature   # Environment variable scenarios
│       │   ├── cli-assertions.feature    # stdout/stderr/exit code assertions
│       │   └── cli-variables.feature     # Variable storage + interpolation
│       └── support/
│           └── setup.ts                  # Custom lifecycle hooks + step definition imports
├── run-project.ts                        # Script: takes project name + forwards args to cucumber-js
└── integration.test.ts                   # bun:test harness — spawns cucumber-js, asserts on output
```

---

## 1. Package.json Scripts

Add to `package.json`:

```json
{
  "scripts": {
    "test:integration": "bun test integration/",
    "test:project": "bun run integration/run-project.ts"
  }
}
```

Usage examples:
```sh
# Run all integration tests (bun:test harness)
bun run test:integration

# Run a specific project's cucumber suite directly
bun run test:project cli

# Forward extra args to cucumber-js
bun run test:project cli --tags @smoke
bun run test:project cli --dry-run
bun run test:project cli --format progress
bun run test:project cli integration/projects/cli/features/cli-execution.feature
```

---

## 2. Project Runner Script (`integration/run-project.ts`)

Takes the first arg as the project name, resolves its `cucumber.yml`, and forwards all
remaining arguments directly to `cucumber-js`.

```ts
import { resolve } from 'node:path'

const [project, ...rest] = process.argv.slice(2)
if (!project) {
  console.error('Usage: bun run test:project <project> [cucumber-js args...]')
  process.exit(1)
}

const root = resolve(import.meta.dir, '..')
const configPath = resolve(root, `integration/projects/${project}/cucumber.yml`)

const proc = Bun.spawn(
  ['bun', 'node_modules/.bin/cucumber-js', '--config', configPath, ...rest],
  { stdout: 'inherit', stderr: 'inherit', cwd: root }
)

process.exit(await proc.exited)
```

---

## 3. Test Project Config (`integration/projects/cli/exo-bdd.config.ts`)

```ts
import { defineConfig } from '../../../src/index.ts'

export default defineConfig({
  adapters: {
    cli: {
      workingDir: process.cwd(),
    },
  },
})
```

---

## 4. Cucumber Config (`integration/projects/cli/cucumber.yml`)

```yaml
default:
  paths:
    - integration/projects/cli/features/**/*.feature
  import:
    - integration/projects/cli/support/setup.ts
  format:
    - summary
```

---

## 5. Support File (`integration/projects/cli/support/setup.ts`)

Custom lifecycle that loads the project-specific config. Does NOT import the default
`lifecycle.ts` hook (which would call `loadConfig()` with no path and fail).

```ts
import { BeforeAll, AfterAll, Before, setWorldConstructor } from '@cucumber/cucumber'
import { loadConfig, createAdapters, TestWorld } from '../../../src/index.ts'
import type { Adapters } from '../../../src/index.ts'
import { resolve } from 'node:path'

// Tagged hooks for adapter validation
import '../../../src/interface/hooks/tagged.ts'

// CLI step definitions
import '../../../src/interface/steps/cli/index.ts'

// Variable step definitions (for interpolation scenarios)
import '../../../src/interface/steps/variables/index.ts'

setWorldConstructor(TestWorld)

let adapters: Adapters

BeforeAll(async function () {
  const configPath = resolve(import.meta.dir, '..', 'exo-bdd.config.ts')
  const config = await loadConfig(configPath)
  adapters = await createAdapters(config)
})

Before(async function (this: TestWorld) {
  if (adapters.cli) this.cli = adapters.cli
  this.reset()
})

AfterAll(async function () {
  await adapters?.dispose()
})
```

---

## 6. Feature Files

### `cli-execution.feature`

```gherkin
@cli
Feature: CLI Command Execution

  Scenario: Run a simple echo command
    When I run "echo hello world"
    Then the command should succeed
    And stdout should contain "hello world"

  Scenario: Run a failing command
    When I run "exit 1"
    Then the command should fail
    And the exit code should be 1

  Scenario: Run a command with inline stdin
    When I run "cat" with stdin "piped input"
    Then the command should succeed
    And stdout should contain "piped input"

  Scenario: Run a command with multiline stdin
    When I run "cat" with stdin:
      """
      line one
      line two
      """
    Then stdout should contain "line one"
    And stdout should contain "line two"
```

### `cli-environment.feature`

```gherkin
@cli
Feature: CLI Environment Variables

  Scenario: Set and use an environment variable
    Given I set environment variable "MY_VAR" to "test_value"
    When I run "echo $MY_VAR"
    Then stdout should contain "test_value"

  Scenario: Override an environment variable
    Given I set environment variable "OVERRIDE_ME" to "first"
    Given I set environment variable "OVERRIDE_ME" to "second"
    When I run "echo $OVERRIDE_ME"
    Then stdout should contain "second"

  Scenario: Clear an environment variable
    Given I set environment variable "TEMP_VAR" to "exists"
    Given I clear environment variable "TEMP_VAR"
    When I run "echo ${TEMP_VAR:-unset}"
    Then stdout should contain "unset"

  Scenario: Set working directory
    Given I set working directory to "/tmp"
    When I run "pwd"
    Then stdout should contain "/tmp"
```

### `cli-assertions.feature`

```gherkin
@cli
Feature: CLI Output Assertions

  Scenario: Assert specific exit code
    When I run "exit 42"
    Then the exit code should be 42
    And the exit code should not be 0

  Scenario: Assert stdout matches regex
    When I run "echo version 1.2.3"
    Then stdout should match "version \\d+\\.\\d+\\.\\d+"

  Scenario: Assert stderr content
    When I run "echo error message >&2"
    Then stderr should contain "error message"

  Scenario: Assert stdout line by line
    When I run "printf 'alpha\nbeta\ngamma\n'"
    Then stdout line 1 should equal "alpha"
    Then stdout line 2 should contain "bet"
    Then stdout line 3 should equal "gamma"

  Scenario: Assert empty stdout and stderr
    When I run "true"
    Then stdout should be empty
    And stderr should be empty

  Scenario: Assert stdout does not contain
    When I run "echo hello"
    Then stdout should not contain "goodbye"

  Scenario: Assert stdout exact match
    When I run "echo exact output"
    Then stdout should equal:
      """
      exact output
      """
```

### `cli-variables.feature`

```gherkin
@cli
Feature: CLI Variable Storage and Interpolation

  Scenario: Store and reuse stdout in a subsequent command
    When I run "echo captured_value"
    Then I store stdout as "output"
    When I run "echo got: ${output}"
    Then stdout should contain "got: captured_value"

  Scenario: Store exit code as variable
    When I run "exit 5"
    Then I store exit code as "code"

  Scenario: Store stderr as variable
    When I run "echo err_content >&2"
    Then I store stderr as "error_output"

  Scenario: Store a specific stdout line
    When I run "printf 'first\nsecond\nthird\n'"
    Then I store stdout line 2 as "second_line"
    When I run "echo ${second_line}"
    Then stdout should contain "second"

  Scenario: Store stdout matching a regex
    When I run "echo version 3.14.1"
    Then I store stdout matching "version (.*)" as "ver"
    When I run "echo ${ver}"
    Then stdout should contain "3.14.1"
```

---

## 7. Integration Test Harness (`integration/integration.test.ts`)

The harness spawns `cucumber-js` via `Bun.spawnSync`, captures stdout/stderr, and makes
assertions. It uses the `--format pretty` formatter for failure tests so that error output
is rich enough for an LLM to diagnose the root cause.

```ts
import { test, expect, describe } from 'bun:test'
import { resolve } from 'node:path'

const ROOT = resolve(import.meta.dir, '..')

interface ProjectResult {
  stdout: string
  stderr: string
  exitCode: number
}

function runProject(project: string, ...extraArgs: string[]): ProjectResult {
  const configPath = resolve(ROOT, `integration/projects/${project}/cucumber.yml`)
  const proc = Bun.spawnSync(
    ['bun', 'node_modules/.bin/cucumber-js', '--config', configPath, ...extraArgs],
    { cwd: ROOT, stdout: 'pipe', stderr: 'pipe', env: { ...process.env } }
  )
  return {
    stdout: new TextDecoder().decode(proc.stdout),
    stderr: new TextDecoder().decode(proc.stderr),
    exitCode: proc.exitCode,
  }
}

/**
 * Formats a ProjectResult into a verbose diagnostic block that gives an LLM
 * (or a human) enough context to understand and resolve a failure without
 * needing to re-run the suite or read additional files.
 *
 * The output intentionally includes:
 *  - The exact exit code (non-zero signals cucumber-js failure)
 *  - Full stdout (contains the Cucumber pretty/summary report with scenario
 *    names, step text, pass/fail markers, assertion diffs, and error stacks)
 *  - Full stderr (contains uncaught exceptions, module resolution errors,
 *    and Bun/Node runtime warnings)
 *
 * This is attached to every failing assertion via expect().fail() so it
 * appears directly in the bun:test output.
 */
function formatFailureReport(result: ProjectResult, context: string): string {
  const border = '='.repeat(72)
  return [
    '',
    border,
    `INTEGRATION TEST FAILURE: ${context}`,
    border,
    '',
    `Exit code: ${result.exitCode}`,
    '',
    '--- cucumber-js stdout ---',
    result.stdout || '(empty)',
    '',
    '--- cucumber-js stderr ---',
    result.stderr || '(empty)',
    '',
    border,
    '',
    'To reproduce this failure, run:',
    `  bun run test:project cli --format pretty`,
    '',
    'To run a single feature in isolation:',
    `  bun run test:project cli --format pretty integration/projects/cli/features/<feature>.feature`,
    '',
  ].join('\n')
}

// ---------------------------------------------------------------------------
// Passing-scenario tests
// ---------------------------------------------------------------------------

describe('Integration: CLI project — passing scenarios', () => {

  test('all CLI scenarios pass with exit code 0', () => {
    const result = runProject('cli')
    if (result.exitCode !== 0) {
      expect().fail(formatFailureReport(result, 'Expected all scenarios to pass'))
    }
    expect(result.exitCode).toBe(0)
  })

  test('summary output reports passed scenarios and zero failures', () => {
    const result = runProject('cli')
    if (result.exitCode !== 0) {
      expect().fail(formatFailureReport(result, 'Cannot check summary — cucumber-js itself failed'))
    }
    expect(result.stdout).toContain('passed')
    expect(result.stdout).not.toContain('failed')
  })

  test('can run a single feature file in isolation', () => {
    const result = runProject(
      'cli',
      'integration/projects/cli/features/cli-execution.feature'
    )
    if (result.exitCode !== 0) {
      expect().fail(formatFailureReport(result, 'Single feature file failed'))
    }
    expect(result.exitCode).toBe(0)
  })

})

// ---------------------------------------------------------------------------
// Failure-scenario tests
//
// These tests intentionally create scenarios that SHOULD fail, then verify
// that cucumber-js:
//   1. Exits with a non-zero code
//   2. Produces a stdout report that is descriptive enough for an LLM to
//      diagnose the root cause without any additional context
//
// We assert on specific fragments of the failure output so that if the error
// reporting degrades, these tests catch it.
// ---------------------------------------------------------------------------

describe('Integration: CLI project — failure reporting', () => {

  /**
   * Helper: writes a temporary .feature file with a deliberately broken
   * scenario, runs it through cucumber-js, and returns the result.
   *
   * Uses Bun.write to create a temp feature file in /tmp, and passes it
   * as a path override to cucumber-js (which overrides the paths in
   * cucumber.yml when a positional argument is provided).
   */
  async function runFailingScenario(
    scenarioName: string,
    featureContent: string,
  ): Promise<ProjectResult> {
    const tmpFile = `/tmp/exo-bdd-fail-${Date.now()}-${Math.random().toString(36).slice(2)}.feature`
    await Bun.write(tmpFile, featureContent)
    try {
      return runProject('cli', '--format', 'pretty', tmpFile)
    } finally {
      try { await Bun.file(tmpFile).exists() && Bun.spawnSync(['rm', tmpFile]) } catch {}
    }
  }

  test('wrong exit code — reports expected vs actual exit code', async () => {
    const result = await runFailingScenario(
      'wrong-exit-code',
      [
        '@cli',
        'Feature: Deliberate failure — wrong exit code',
        '',
        '  Scenario: Expect exit 0 but command exits with 1',
        '    When I run "exit 1"',
        '    Then the exit code should be 0',
      ].join('\n'),
    )

    // cucumber-js must exit non-zero
    expect(result.exitCode).not.toBe(0)

    // The failure report must mention the scenario name so the reader knows WHICH test broke
    expect(result.stdout).toContain('Expect exit 0 but command exits with 1')

    // The report must show the failing step text so the reader knows WHERE it broke
    expect(result.stdout).toContain('the exit code should be 0')

    // The report must contain the assertion diff (expected vs received) so the reader
    // knows WHAT went wrong and can fix it without guessing
    expect(result.stdout + result.stderr).toMatch(/expected.*0/i)

    // The report must mark the scenario as failed
    expect(result.stdout).toMatch(/failed/i)
  })

  test('wrong stdout content — reports expected string vs actual stdout', async () => {
    const result = await runFailingScenario(
      'wrong-stdout',
      [
        '@cli',
        'Feature: Deliberate failure — wrong stdout content',
        '',
        '  Scenario: Expect stdout to contain a string that is not there',
        '    When I run "echo actual output here"',
        '    Then stdout should contain "this text does not exist"',
      ].join('\n'),
    )

    expect(result.exitCode).not.toBe(0)

    // Must name the scenario
    expect(result.stdout).toContain('Expect stdout to contain a string that is not there')

    // Must show the failing step
    expect(result.stdout).toContain('stdout should contain "this text does not exist"')

    // Must include the actual stdout value OR the expected string in the error
    // so the reader can see the mismatch
    const combined = result.stdout + result.stderr
    expect(combined).toMatch(/this text does not exist|actual output here/i)

    expect(result.stdout).toMatch(/failed/i)
  })

  test('wrong stderr content — reports expected vs actual stderr', async () => {
    const result = await runFailingScenario(
      'wrong-stderr',
      [
        '@cli',
        'Feature: Deliberate failure — wrong stderr content',
        '',
        '  Scenario: Expect stderr to contain text but stderr has different content',
        '    When I run "echo real error >&2"',
        '    Then stderr should contain "expected error"',
      ].join('\n'),
    )

    expect(result.exitCode).not.toBe(0)
    expect(result.stdout).toContain('Expect stderr to contain text but stderr has different content')
    expect(result.stdout).toContain('stderr should contain "expected error"')
    expect(result.stdout).toMatch(/failed/i)
  })

  test('regex mismatch — reports the pattern that did not match', async () => {
    const result = await runFailingScenario(
      'regex-mismatch',
      [
        '@cli',
        'Feature: Deliberate failure — regex mismatch',
        '',
        '  Scenario: Expect stdout to match a regex that does not match',
        '    When I run "echo no numbers here"',
        '    Then stdout should match "\\\\d{3}-\\\\d{4}"',
      ].join('\n'),
    )

    expect(result.exitCode).not.toBe(0)
    expect(result.stdout).toContain('Expect stdout to match a regex that does not match')
    expect(result.stdout).toContain('stdout should match')
    expect(result.stdout).toMatch(/failed/i)
  })

  test('success-expected-but-failed — reports the unexpected non-zero exit', async () => {
    const result = await runFailingScenario(
      'success-expected',
      [
        '@cli',
        'Feature: Deliberate failure — expected success',
        '',
        '  Scenario: Expect command to succeed but it exits with error',
        '    When I run "exit 2"',
        '    Then the command should succeed',
      ].join('\n'),
    )

    expect(result.exitCode).not.toBe(0)
    expect(result.stdout).toContain('Expect command to succeed but it exits with error')
    expect(result.stdout).toContain('the command should succeed')
    expect(result.stdout).toMatch(/failed/i)
  })

  test('failure report at the end includes scenario count with failures', async () => {
    const result = await runFailingScenario(
      'summary-check',
      [
        '@cli',
        'Feature: Deliberate failure — summary verification',
        '',
        '  Scenario: A passing scenario',
        '    When I run "echo ok"',
        '    Then the command should succeed',
        '',
        '  Scenario: A failing scenario for summary check',
        '    When I run "echo ok"',
        '    Then the exit code should be 99',
      ].join('\n'),
    )

    expect(result.exitCode).not.toBe(0)

    // The summary report at the end should include a breakdown like:
    //   "2 scenarios (1 passed, 1 failed)"
    //   "N steps (X passed, Y failed)"
    // This gives readers (humans or LLMs) a quick triage overview.
    const combined = result.stdout + result.stderr
    expect(combined).toMatch(/scenario/i)
    expect(combined).toMatch(/failed/i)
    expect(combined).toMatch(/passed/i)
  })

  test('undefined step — reports the step as undefined with a snippet', async () => {
    const result = await runFailingScenario(
      'undefined-step',
      [
        '@cli',
        'Feature: Deliberate failure — undefined step',
        '',
        '  Scenario: Use a step that does not exist',
        '    When I run "echo ok"',
        '    Then the frobnitz should be activated',
      ].join('\n'),
    )

    // cucumber-js exits non-zero for undefined steps (with --strict, which is
    // the default in cucumber-js v12)
    expect(result.exitCode).not.toBe(0)

    // Must mention the undefined step so the reader knows which step to define
    expect(result.stdout + result.stderr).toContain('frobnitz')

    // cucumber-js should suggest a snippet implementation
    const combined = result.stdout + result.stderr
    expect(combined).toMatch(/undefined|pending|snippet/i)
  })

})
```

---

## 8. TypeScript Loading

Cucumber-js runs under Node by default. Since all support files and configs are `.ts`, we
run cucumber-js via Bun (`bun node_modules/.bin/cucumber-js ...`), which handles TypeScript
natively. This avoids adding `tsx` or `ts-node` as dev dependencies.

---

## 9. Implementation Checklist

| # | File | Action | Description |
|---|------|--------|-------------|
| 1 | `integration/run-project.ts` | Create | Script: project name → cucumber-js config, forwards remaining args |
| 2 | `integration/projects/cli/exo-bdd.config.ts` | Create | `defineConfig()` with CLI adapter |
| 3 | `integration/projects/cli/cucumber.yml` | Create | Cucumber-js profile: paths, imports, format |
| 4 | `integration/projects/cli/support/setup.ts` | Create | Custom lifecycle hooks + step/hook imports |
| 5 | `integration/projects/cli/features/cli-execution.feature` | Create | Command execution scenarios |
| 6 | `integration/projects/cli/features/cli-environment.feature` | Create | Environment variable scenarios |
| 7 | `integration/projects/cli/features/cli-assertions.feature` | Create | Output assertion scenarios |
| 8 | `integration/projects/cli/features/cli-variables.feature` | Create | Variable storage/interpolation scenarios |
| 9 | `integration/integration.test.ts` | Create | bun:test harness with pass + failure assertions |
| 10 | `package.json` | Modify | Add `test:integration` and `test:project` scripts |

---

## 10. Potential Issues

- **Duplicate `setWorldConstructor`**: `support/setup.ts` must NOT import `lifecycle.ts`
  (which also calls `setWorldConstructor`). It handles lifecycle setup itself.
- **`--import` vs `--require`**: ESM `.ts` files via Bun use `import:` in `cucumber.yml`.
  `require:` is for CommonJS only.
- **Variable syntax in Gherkin**: `${var}` inside quoted step parameter strings passes
  through Cucumber unmodified and is interpolated at runtime by `InterpolationService`.
- **Temp feature files in failure tests**: Written to `/tmp`, cleaned up in a `finally`
  block. If cleanup fails, stale files in `/tmp` are harmless.
- **`--format pretty` for failure tests**: The `pretty` formatter outputs scenario names,
  step text, and error details inline — essential for the failure assertions to work.
  The default `summary` formatter is used for the passing tests (less noise).

---

## 11. Extensibility

Adding integration tests for another adapter (e.g., HTTP):
1. Create `integration/projects/http/` with its own config, cucumber.yml, support/, features/
2. The harness calls `runProject('http')` — same pattern
3. `bun run test:project http` works immediately
