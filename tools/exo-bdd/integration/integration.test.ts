import { test, expect, describe } from 'bun:test'
import { resolve } from 'node:path'

const ROOT = resolve(import.meta.dir, '..')

interface ProjectResult {
  stdout: string
  stderr: string
  exitCode: number
}

function runProject(project: string, ...extraArgs: string[]): ProjectResult {
  const configPath = `integration/projects/${project}/cucumber.yml`
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
    featureContent: string,
  ): Promise<ProjectResult> {
    const tmpFile = `/tmp/exo-bdd-fail-${Date.now()}-${Math.random().toString(36).slice(2)}.feature`
    await Bun.write(tmpFile, featureContent)
    try {
      return runProject('cli', '--format', 'pretty', tmpFile)
    } finally {
      try { Bun.spawnSync(['rm', '-f', tmpFile]) } catch {}
    }
  }

  test('wrong exit code — reports expected vs actual exit code', async () => {
    const result = await runFailingScenario(
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
