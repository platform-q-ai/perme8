import { test, expect, describe, beforeEach, mock } from 'bun:test'
import { VariableService } from '../../../src/application/services/VariableService.ts'
import { InterpolationService } from '../../../src/application/services/InterpolationService.ts'

// Mock Cucumber so the step-file-level Given/When/Then registrations are no-ops
mock.module('@cucumber/cucumber', () => ({
  Given: mock(),
  When: mock(),
  Then: mock(),
  Before: mock(),
  After: mock(),
  BeforeAll: mock(),
  AfterAll: mock(),
  setWorldConstructor: mock(),
  World: class MockWorld { constructor() {} },
  Status: { FAILED: 'FAILED', PASSED: 'PASSED' },
  default: {},
}))

// Mock @playwright/test so assertion handlers use a working expect
mock.module('@playwright/test', () => ({
  expect,
  default: {},
}))

// Dynamic imports after mocks so Cucumber registrations run harmlessly
const {
  setVariableString,
  setVariableInt,
  setVariableDocString,
  assertVariableEqualsString,
  assertVariableEqualsInt,
  assertVariableExists,
  assertVariableNotExists,
  assertVariableContains,
  assertVariableMatches,
} = await import('../../../src/interface/steps/variables.steps.ts')

/**
 * Tests for variable step definition logic.
 *
 * These tests import and invoke the actual exported handler functions from
 * variables.steps.ts, passing a mock world that satisfies VariablesContext.
 */

interface MockWorld {
  setVariable(name: string, value: unknown): void
  getVariable(name: string): unknown
  hasVariable(name: string): boolean
  interpolate(text: string): string
}

function createMockWorld(): MockWorld {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)
  return {
    setVariable: (name, value) => variableService.set(name, value),
    getVariable: (name) => variableService.get(name),
    hasVariable: (name) => variableService.has(name),
    interpolate: (text) => interpolationService.interpolate(text),
  }
}

describe('Variable Steps', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // ─── Given 'I set variable {string} to {string}' ──────────────────────

  describe('I set variable {string} to {string}', () => {
    test('stores a string value', () => {
      setVariableString(world, 'greeting', 'hello')

      expect(world.getVariable('greeting')).toBe('hello')
    })

    test('interpolates the value before storing', () => {
      // Set a variable that will be referenced in interpolation
      world.setVariable('host', 'localhost')

      setVariableString(world, 'url', 'http://${host}/api')

      expect(world.getVariable('url')).toBe('http://localhost/api')
    })
  })

  // ─── Given 'I set variable {string} to {int}' ─────────────────────────

  describe('I set variable {string} to {int}', () => {
    test('stores a numeric value', () => {
      setVariableInt(world, 'count', 42)

      expect(world.getVariable('count')).toBe(42)
    })
  })

  // ─── Given 'I set variable {string} to:' (doc string) ─────────────────

  describe('I set variable {string} to: (doc string)', () => {
    test('parses valid JSON doc string', () => {
      setVariableDocString(world, 'payload', '{"key": "value", "num": 123}')

      const stored = world.getVariable('payload') as Record<string, unknown>
      expect(stored).toEqual({ key: 'value', num: 123 })
    })

    test('falls back to plain string for non-JSON doc string', () => {
      setVariableDocString(world, 'message', 'This is just plain text, not JSON')

      expect(world.getVariable('message')).toBe('This is just plain text, not JSON')
    })
  })

  // ─── Then 'the variable {string} should equal {string}' ───────────────

  describe('the variable {string} should equal {string}', () => {
    test('passes when values match', () => {
      world.setVariable('color', 'blue')

      assertVariableEqualsString(world, 'color', 'blue')
    })

    test('fails when values do not match', () => {
      world.setVariable('color', 'blue')

      expect(() => {
        assertVariableEqualsString(world, 'color', 'red')
      }).toThrow()
    })
  })

  // ─── Then 'the variable {string} should equal {int}' ──────────────────

  describe('the variable {string} should equal {int}', () => {
    test('passes when numeric values match', () => {
      world.setVariable('count', 99)

      assertVariableEqualsInt(world, 'count', 99)
    })
  })

  // ─── Then 'the variable {string} should exist' ────────────────────────

  describe('the variable {string} should exist', () => {
    test('passes when variable exists', () => {
      world.setVariable('token', 'abc123')

      assertVariableExists(world, 'token')
    })
  })

  // ─── Then 'the variable {string} should not exist' ────────────────────

  describe('the variable {string} should not exist', () => {
    test('passes when variable does not exist', () => {
      assertVariableNotExists(world, 'nonexistent')
    })
  })

  // ─── Then 'the variable {string} should contain {string}' ─────────────

  describe('the variable {string} should contain {string}', () => {
    test('passes when variable value contains substring', () => {
      world.setVariable('message', 'Hello, World!')

      assertVariableContains(world, 'message', 'World')
    })
  })

  // ─── Then 'the variable {string} should match {string}' ───────────────

  describe('the variable {string} should match {string}', () => {
    test('passes when variable value matches regex', () => {
      world.setVariable('email', 'test@example.com')

      assertVariableMatches(world, 'email', '^\\S+@\\S+\\.\\S+$')
    })

    test('fails when variable value does not match regex', () => {
      world.setVariable('email', 'not-an-email')

      expect(() => {
        assertVariableMatches(world, 'email', '^\\S+@\\S+\\.\\S+$')
      }).toThrow()
    })
  })
})
