import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'

export interface AssertionContext {
  cli: {
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

export function assertExitCode(context: AssertionContext, expectedCode: number): void {
  expect(context.cli.exitCode).toBe(expectedCode)
}

export function assertExitCodeNot(context: AssertionContext, unexpectedCode: number): void {
  expect(context.cli.exitCode).not.toBe(unexpectedCode)
}

export function assertCommandSucceeded(context: AssertionContext): void {
  expect(context.cli.exitCode).toBe(0)
}

export function assertCommandFailed(context: AssertionContext): void {
  expect(context.cli.exitCode).not.toBe(0)
}

export function assertStdoutContains(context: AssertionContext, expected: string): void {
  expect(context.cli.stdout).toContain(context.interpolate(expected))
}

export function assertStdoutNotContains(context: AssertionContext, unexpected: string): void {
  expect(context.cli.stdout).not.toContain(context.interpolate(unexpected))
}

export function assertStdoutMatches(context: AssertionContext, pattern: string): void {
  expect(context.cli.stdout).toMatch(new RegExp(pattern))
}

export function assertStderrContains(context: AssertionContext, expected: string): void {
  expect(context.cli.stderr).toContain(context.interpolate(expected))
}

export function assertStderrNotContains(context: AssertionContext, unexpected: string): void {
  expect(context.cli.stderr).not.toContain(context.interpolate(unexpected))
}

export function assertStderrEmpty(context: AssertionContext): void {
  expect(context.cli.stderr.trim()).toBe('')
}

export function assertStdoutEmpty(context: AssertionContext): void {
  expect(context.cli.stdout.trim()).toBe('')
}

export function assertStdoutEquals(context: AssertionContext, docString: string): void {
  expect(context.cli.stdout.trim()).toBe(context.interpolate(docString).trim())
}

export function assertStdoutLineEquals(context: AssertionContext, lineNumber: number, expected: string): void {
  const line = context.cli.stdoutLine(lineNumber)
  expect(line).toBe(context.interpolate(expected))
}

export function assertStdoutLineContains(context: AssertionContext, lineNumber: number, expected: string): void {
  const line = context.cli.stdoutLine(lineNumber)
  expect(line).toContain(context.interpolate(expected))
}

export function assertStderrMatches(context: AssertionContext, pattern: string): void {
  expect(context.cli.stderr).toMatch(new RegExp(pattern))
}

export function assertCommandCompletedWithin(context: AssertionContext, maxSeconds: number): void {
  expect(context.cli.duration).toBeLessThanOrEqual(maxSeconds * 1000)
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
