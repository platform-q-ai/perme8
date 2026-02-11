import { Given, Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../world/index.ts'

/** Context required by variable step handlers. */
export interface VariablesContext {
  setVariable(name: string, value: unknown): void
  getVariable(name: string): unknown
  hasVariable(name: string): boolean
  interpolate(text: string): string
}

export function setVariableString(ctx: VariablesContext, name: string, value: string) {
  ctx.setVariable(name, ctx.interpolate(value))
}

export function setVariableInt(ctx: VariablesContext, name: string, value: number) {
  ctx.setVariable(name, value)
}

export function setVariableDocString(ctx: VariablesContext, name: string, docString: string) {
  try {
    ctx.setVariable(name, JSON.parse(ctx.interpolate(docString)))
  } catch {
    ctx.setVariable(name, ctx.interpolate(docString))
  }
}

export function assertVariableEqualsString(ctx: VariablesContext, name: string, expected: string) {
  const actual = ctx.getVariable(name)
  expect(actual).toBe(ctx.interpolate(expected))
}

export function assertVariableEqualsInt(ctx: VariablesContext, name: string, expected: number) {
  const actual = ctx.getVariable(name)
  expect(actual).toBe(expected)
}

export function assertVariableExists(ctx: VariablesContext, name: string) {
  expect(ctx.hasVariable(name)).toBe(true)
}

export function assertVariableNotExists(ctx: VariablesContext, name: string) {
  expect(ctx.hasVariable(name)).toBe(false)
}

export function assertVariableContains(ctx: VariablesContext, name: string, expected: string) {
  const actual = String(ctx.getVariable(name))
  expect(actual).toContain(ctx.interpolate(expected))
}

export function assertVariableMatches(ctx: VariablesContext, name: string, pattern: string) {
  const actual = String(ctx.getVariable(name))
  expect(actual).toMatch(new RegExp(pattern))
}

// ── Cucumber registrations (delegate to exported handlers) ────────────────

Given<TestWorld>('I set variable {string} to {string}', function (n: string, v: string) { setVariableString(this, n, v) })
Given<TestWorld>('I set variable {string} to {int}', function (n: string, v: number) { setVariableInt(this, n, v) })
Given<TestWorld>('I set variable {string} to:', function (n: string, d: string) { setVariableDocString(this, n, d) })
Then<TestWorld>('the variable {string} should equal {string}', function (n: string, v: string) { assertVariableEqualsString(this, n, v) })
Then<TestWorld>('the variable {string} should equal {int}', function (n: string, v: number) { assertVariableEqualsInt(this, n, v) })
Then<TestWorld>('the variable {string} should exist', function (n: string) { assertVariableExists(this, n) })
Then<TestWorld>('the variable {string} should not exist', function (n: string) { assertVariableNotExists(this, n) })
Then<TestWorld>('the variable {string} should contain {string}', function (n: string, v: string) { assertVariableContains(this, n, v) })
Then<TestWorld>('the variable {string} should match {string}', function (n: string, p: string) { assertVariableMatches(this, n, p) })
