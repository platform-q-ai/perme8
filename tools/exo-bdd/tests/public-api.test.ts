import { test, expect, describe, mock } from 'bun:test'

// Mock external dependencies before importing the public API
mock.module('@cucumber/cucumber', () => ({
  World: class MockWorld {
    constructor() {}
  },
  Given: mock(),
  When: mock(),
  Then: mock(),
  Before: mock(),
  After: mock(),
  BeforeAll: mock(),
  AfterAll: mock(),
  setWorldConstructor: mock(),
  Status: { FAILED: 'FAILED', PASSED: 'PASSED' },
  default: {},
}))

mock.module('@playwright/test', () => ({
  request: {
    newContext: mock(() => Promise.resolve({})),
  },
  chromium: {
    launch: mock(() => Promise.resolve({})),
  },
  expect: (v: unknown) => ({
    toBe: () => {},
    toContain: () => {},
    toMatch: () => {},
    toEqual: () => {},
    toHaveLength: () => {},
    toBeDefined: () => {},
    toBeUndefined: () => {},
    toBeNull: () => {},
    toBeGreaterThanOrEqual: () => {},
    toBeLessThan: () => {},
    toBeLessThanOrEqual: () => {},
    not: {
      toBe: () => {},
      toContain: () => {},
      toBeVisible: () => {},
    },
    first: () => ({
      toBeVisible: () => {},
    }),
  }),
  default: {},
}))

mock.module('neo4j-driver', () => ({
  default: {
    driver: mock(() => ({})),
    auth: { basic: mock(() => ({})) },
  },
}))

mock.module('jsonpath', () => ({
  default: { query: () => [] },
}))

// Dynamic import after mocking
const api = await import('../src/index.ts')

describe('Public API exports', () => {
  test('exports defineConfig function', () => {
    expect(typeof api.defineConfig).toBe('function')
  })

  test('exports loadConfig function', () => {
    expect(typeof api.loadConfig).toBe('function')
  })

  test('exports createAdapters function', () => {
    expect(typeof api.createAdapters).toBe('function')
  })

  test('exports TestWorld class', () => {
    expect(typeof api.TestWorld).toBe('function')
  })

  test('exports RiskLevel value object', () => {
    expect(api.RiskLevel.High).toBe('High')
    expect(api.RiskLevel.Medium).toBe('Medium')
    expect(api.RiskLevel.Low).toBe('Low')
    expect(api.RiskLevel.Informational).toBe('Informational')
    expect(typeof api.RiskLevel.compare).toBe('function')
    expect(typeof api.RiskLevel.isAtLeast).toBe('function')
  })

  test('exports JsonPath class', () => {
    expect(typeof api.JsonPath).toBe('function')
    const path = new api.JsonPath('$.test')
    expect(path.expression).toBe('$.test')
  })

  test('exports DomainError class', () => {
    expect(typeof api.DomainError).toBe('function')
  })

  test('exports VariableNotFoundError class', () => {
    expect(typeof api.VariableNotFoundError).toBe('function')
    const error = new api.VariableNotFoundError('test')
    expect(error).toBeInstanceOf(api.DomainError)
    expect(error.code).toBe('VARIABLE_NOT_FOUND')
  })

  test('exports AdapterNotConfiguredError class', () => {
    expect(typeof api.AdapterNotConfiguredError).toBe('function')
    const error = new api.AdapterNotConfiguredError('http')
    expect(error).toBeInstanceOf(api.DomainError)
    expect(error.code).toBe('ADAPTER_NOT_CONFIGURED')
  })

  test('exports VariableService class', () => {
    expect(typeof api.VariableService).toBe('function')
    const service = new api.VariableService()
    service.set('key', 'value')
    expect(service.get<string>('key')).toBe('value')
  })

  test('exports InterpolationService class', () => {
    expect(typeof api.InterpolationService).toBe('function')
    const vars = new api.VariableService()
    const service = new api.InterpolationService(vars)
    expect(typeof service.interpolate).toBe('function')
  })

  test('does not export internal infrastructure adapters', () => {
    // PlaywrightHttpAdapter, PlaywrightBrowserAdapter, etc. should not be directly exported
    expect((api as Record<string, unknown>)['PlaywrightHttpAdapter']).toBeUndefined()
    expect((api as Record<string, unknown>)['PlaywrightBrowserAdapter']).toBeUndefined()
    expect((api as Record<string, unknown>)['BunCliAdapter']).toBeUndefined()
    expect((api as Record<string, unknown>)['Neo4jGraphAdapter']).toBeUndefined()
    expect((api as Record<string, unknown>)['ZapSecurityAdapter']).toBeUndefined()
  })

  test('does not export internal factories directly', () => {
    // AdapterFactory is not a named export; only createAdapters is
    expect((api as Record<string, unknown>)['AdapterFactory']).toBeUndefined()
  })

  test('type exports are importable', () => {
    // Verify that the module exports the expected keys
    // Type-only exports don't show at runtime, but we verify the module shape
    const exportKeys = Object.keys(api)
    // Runtime exports should include these:
    expect(exportKeys).toContain('defineConfig')
    expect(exportKeys).toContain('loadConfig')
    expect(exportKeys).toContain('createAdapters')
    expect(exportKeys).toContain('TestWorld')
    expect(exportKeys).toContain('RiskLevel')
    expect(exportKeys).toContain('JsonPath')
    expect(exportKeys).toContain('DomainError')
    expect(exportKeys).toContain('VariableNotFoundError')
    expect(exportKeys).toContain('AdapterNotConfiguredError')
    expect(exportKeys).toContain('VariableService')
    expect(exportKeys).toContain('InterpolationService')
  })
})
