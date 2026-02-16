import { Then } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

export interface AssertionContext {
  cli: {
    lastCommand?: string
    exitCode: number
    stdout: string
    stderr: string
    duration: number
    stdoutLine(lineNumber: number): string
    stdoutMatching(pattern: RegExp): string | null
  }
  interpolate(value: string): string
  setVariable(name: string, value: unknown): void
}

/**
 * Truncates a string to maxLen characters, appending "..." if truncated.
 */
function truncate(s: string, maxLen = 500): string {
  const trimmed = s.trim()
  if (trimmed.length <= maxLen) return trimmed
  return trimmed.slice(0, maxLen) + '...'
}

/**
 * Builds a context block showing the last command, exit code, stdout, and stderr.
 * Appended to assertion error messages for easier debugging.
 */
function commandContext(context: AssertionContext): string {
  const parts: string[] = []
  if (context.cli.lastCommand) {
    parts.push(`  command: ${context.cli.lastCommand}`)
  }
  parts.push(`  exit code: ${context.cli.exitCode}`)
  if (context.cli.stdout.trim()) {
    parts.push(`  stdout: ${truncate(context.cli.stdout)}`)
  }
  if (context.cli.stderr.trim()) {
    parts.push(`  stderr: ${truncate(context.cli.stderr)}`)
  }
  return parts.join('\n')
}

export function assertExitCode(context: AssertionContext, expectedCode: number): void {
  if (context.cli.exitCode !== expectedCode) {
    throw new Error(
      `Expected exit code ${expectedCode} but got ${context.cli.exitCode}\n${commandContext(context)}`
    )
  }
}

export function assertExitCodeNot(context: AssertionContext, unexpectedCode: number): void {
  if (context.cli.exitCode === unexpectedCode) {
    throw new Error(
      `Expected exit code to NOT be ${unexpectedCode}\n${commandContext(context)}`
    )
  }
}

export function assertCommandSucceeded(context: AssertionContext): void {
  if (context.cli.exitCode !== 0) {
    throw new Error(
      `Command failed (expected exit code 0, got ${context.cli.exitCode})\n${commandContext(context)}`
    )
  }
}

export function assertCommandFailed(context: AssertionContext): void {
  if (context.cli.exitCode === 0) {
    throw new Error(
      `Command succeeded but was expected to fail (exit code 0)\n${commandContext(context)}`
    )
  }
}

export function assertStdoutContains(context: AssertionContext, expected: string): void {
  const interpolated = context.interpolate(expected)
  if (!context.cli.stdout.includes(interpolated)) {
    throw new Error(
      `stdout does not contain "${interpolated}"\n${commandContext(context)}`
    )
  }
}

export function assertStdoutNotContains(context: AssertionContext, unexpected: string): void {
  const interpolated = context.interpolate(unexpected)
  if (context.cli.stdout.includes(interpolated)) {
    throw new Error(
      `stdout should not contain "${interpolated}" but it does\n${commandContext(context)}`
    )
  }
}

export function assertStdoutMatches(context: AssertionContext, pattern: string): void {
  const regex = new RegExp(pattern)
  if (!regex.test(context.cli.stdout)) {
    throw new Error(
      `stdout does not match pattern /${pattern}/\n${commandContext(context)}`
    )
  }
}

export function assertStderrContains(context: AssertionContext, expected: string): void {
  const interpolated = context.interpolate(expected)
  if (!context.cli.stderr.includes(interpolated)) {
    throw new Error(
      `stderr does not contain "${interpolated}"\n${commandContext(context)}`
    )
  }
}

export function assertStderrNotContains(context: AssertionContext, unexpected: string): void {
  const interpolated = context.interpolate(unexpected)
  if (context.cli.stderr.includes(interpolated)) {
    throw new Error(
      `stderr should not contain "${interpolated}" but it does\n${commandContext(context)}`
    )
  }
}

export function assertStderrEmpty(context: AssertionContext): void {
  if (context.cli.stderr.trim() !== '') {
    throw new Error(
      `stderr should be empty but contains output\n${commandContext(context)}`
    )
  }
}

export function assertStdoutEmpty(context: AssertionContext): void {
  if (context.cli.stdout.trim() !== '') {
    throw new Error(
      `stdout should be empty but contains output\n${commandContext(context)}`
    )
  }
}

export function assertStdoutEquals(context: AssertionContext, docString: string): void {
  const expected = context.interpolate(docString).trim()
  const actual = context.cli.stdout.trim()
  if (actual !== expected) {
    throw new Error(
      `stdout does not equal expected value\n  expected: ${truncate(expected)}\n  actual:   ${truncate(actual)}\n${commandContext(context)}`
    )
  }
}

export function assertStdoutLineEquals(context: AssertionContext, lineNumber: number, expected: string): void {
  const line = context.cli.stdoutLine(lineNumber)
  const interpolated = context.interpolate(expected)
  if (line !== interpolated) {
    throw new Error(
      `stdout line ${lineNumber} does not equal "${interpolated}"\n  actual: "${line}"\n${commandContext(context)}`
    )
  }
}

export function assertStdoutLineContains(context: AssertionContext, lineNumber: number, expected: string): void {
  const line = context.cli.stdoutLine(lineNumber)
  const interpolated = context.interpolate(expected)
  if (!line.includes(interpolated)) {
    throw new Error(
      `stdout line ${lineNumber} does not contain "${interpolated}"\n  actual: "${line}"\n${commandContext(context)}`
    )
  }
}

export function assertStderrMatches(context: AssertionContext, pattern: string): void {
  const regex = new RegExp(pattern)
  if (!regex.test(context.cli.stderr)) {
    throw new Error(
      `stderr does not match pattern /${pattern}/\n${commandContext(context)}`
    )
  }
}

export function assertCommandCompletedWithin(context: AssertionContext, maxSeconds: number): void {
  const maxMs = maxSeconds * 1000
  if (context.cli.duration > maxMs) {
    throw new Error(
      `Command took ${context.cli.duration}ms (limit: ${maxMs}ms)\n${commandContext(context)}`
    )
  }
}

export function storeStdout(context: AssertionContext, variableName: string): void {
  context.setVariable(variableName, context.cli.stdout.trim())
}

export function storeStderr(context: AssertionContext, variableName: string): void {
  context.setVariable(variableName, context.cli.stderr.trim())
}

export function storeExitCode(context: AssertionContext, variableName: string): void {
  context.setVariable(variableName, context.cli.exitCode)
}

export function storeStdoutLine(context: AssertionContext, lineNumber: number, variableName: string): void {
  context.setVariable(variableName, context.cli.stdoutLine(lineNumber))
}

export function storeStdoutMatching(context: AssertionContext, pattern: string, variableName: string): void {
  const match = context.cli.stdoutMatching(new RegExp(pattern))
  context.setVariable(variableName, match)
}

Then<TestWorld>(
  'the exit code should be {int}',
  function (expectedCode: number) {
    assertExitCode(this, expectedCode)
  },
)

Then<TestWorld>(
  'the exit code should not be {int}',
  function (unexpectedCode: number) {
    assertExitCodeNot(this, unexpectedCode)
  },
)

Then<TestWorld>(
  'the command should succeed',
  function () {
    assertCommandSucceeded(this)
  },
)

Then<TestWorld>(
  'the command should fail',
  function () {
    assertCommandFailed(this)
  },
)

Then<TestWorld>(
  'stdout should contain {string}',
  function (expected: string) {
    assertStdoutContains(this, expected)
  },
)

Then<TestWorld>(
  'stdout should not contain {string}',
  function (unexpected: string) {
    assertStdoutNotContains(this, unexpected)
  },
)

Then<TestWorld>(
  'stdout should match {string}',
  function (pattern: string) {
    assertStdoutMatches(this, pattern)
  },
)

Then<TestWorld>(
  'stderr should contain {string}',
  function (expected: string) {
    assertStderrContains(this, expected)
  },
)

Then<TestWorld>(
  'stderr should not contain {string}',
  function (unexpected: string) {
    assertStderrNotContains(this, unexpected)
  },
)

Then<TestWorld>(
  'stderr should be empty',
  function () {
    assertStderrEmpty(this)
  },
)

Then<TestWorld>(
  'stdout should be empty',
  function () {
    assertStdoutEmpty(this)
  },
)

Then<TestWorld>(
  'stdout should equal:',
  function (docString: string) {
    assertStdoutEquals(this, docString)
  },
)

Then<TestWorld>(
  'stdout line {int} should equal {string}',
  function (lineNumber: number, expected: string) {
    assertStdoutLineEquals(this, lineNumber, expected)
  },
)

Then<TestWorld>(
  'stdout line {int} should contain {string}',
  function (lineNumber: number, expected: string) {
    assertStdoutLineContains(this, lineNumber, expected)
  },
)

Then<TestWorld>(
  'stderr should match {string}',
  function (pattern: string) {
    assertStderrMatches(this, pattern)
  },
)

Then<TestWorld>(
  'the command should complete within {int} seconds',
  function (maxSeconds: number) {
    assertCommandCompletedWithin(this, maxSeconds)
  },
)

Then<TestWorld>(
  'I store stdout as {string}',
  function (variableName: string) {
    storeStdout(this, variableName)
  },
)

Then<TestWorld>(
  'I store stderr as {string}',
  function (variableName: string) {
    storeStderr(this, variableName)
  },
)

Then<TestWorld>(
  'I store exit code as {string}',
  function (variableName: string) {
    storeExitCode(this, variableName)
  },
)

Then<TestWorld>(
  'I store stdout line {int} as {string}',
  function (lineNumber: number, variableName: string) {
    storeStdoutLine(this, lineNumber, variableName)
  },
)

Then<TestWorld>(
  'I store stdout matching {string} as {string}',
  function (pattern: string, variableName: string) {
    storeStdoutMatching(this, pattern, variableName)
  },
)
