import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'

export interface QueryContext {
  interpolate(value: string): string
  setVariable(name: string, value: unknown): void
  graph: {
    count: number
    records: Record<string, unknown>[]
  }
}

// Query Result Assertions
export function assertResultEmpty(context: QueryContext): void {
  expect(context.graph.count).toBe(0)
}

export function assertResultRowCount(context: QueryContext, expectedCount: number): void {
  expect(context.graph.count).toBe(expectedCount)
}

export function assertResultMinRowCount(context: QueryContext, minCount: number): void {
  expect(context.graph.count).toBeGreaterThanOrEqual(minCount)
}

export function assertResultPathEquals(context: QueryContext, path: string, expectedValue: string): void {
  const records = context.graph.records
  expect(records.length).toBeGreaterThan(0)
  const keys = path.split('.')
  let value: unknown = records[0]
  for (const key of keys) {
    value = (value as Record<string, unknown>)[key]
  }
  expect(String(value)).toBe(context.interpolate(expectedValue))
}

export function assertResultPathContains(context: QueryContext, path: string, expectedSubstring: string): void {
  const records = context.graph.records
  expect(records.length).toBeGreaterThan(0)
  const keys = path.split('.')
  let value: unknown = records[0]
  for (const key of keys) {
    value = (value as Record<string, unknown>)[key]
  }
  expect(String(value)).toContain(context.interpolate(expectedSubstring))
}

// Variable Storage
export function storeResult(context: QueryContext, variableName: string): void {
  context.setVariable(variableName, context.graph.records)
}

export function storeResultCount(context: QueryContext, variableName: string): void {
  context.setVariable(variableName, context.graph.count)
}

// Cucumber Registrations
Then<TestWorld>('the result should be empty', function () {
  assertResultEmpty(this)
})

Then<TestWorld>('the result should have {int} rows', function (expectedCount: number) {
  assertResultRowCount(this, expectedCount)
})

Then<TestWorld>('the result should have at least {int} rows', function (minCount: number) {
  assertResultMinRowCount(this, minCount)
})

Then<TestWorld>(
  'the result path {string} should equal {string}',
  function (path: string, expectedValue: string) {
    assertResultPathEquals(this, path, expectedValue)
  },
)

Then<TestWorld>(
  'the result path {string} should contain {string}',
  function (path: string, expectedSubstring: string) {
    assertResultPathContains(this, path, expectedSubstring)
  },
)

Then<TestWorld>('I store the result as {string}', function (variableName: string) {
  storeResult(this, variableName)
})

Then<TestWorld>('I store the result count as {string}', function (variableName: string) {
  storeResultCount(this, variableName)
})
