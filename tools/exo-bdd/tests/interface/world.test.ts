import { test, expect, describe, beforeEach, mock } from 'bun:test'

// --- Mock @cucumber/cucumber ---

mock.module('@cucumber/cucumber', () => ({
  World: class FakeWorld {
    attach = mock(() => {})
    constructor(_options: unknown) {}
  },
  Before: () => {},
  After: () => {},
  BeforeAll: () => {},
  AfterAll: () => {},
  setWorldConstructor: () => {},
  Status: { FAILED: 'FAILED', PASSED: 'PASSED' },
}))

// --- Import after mocking ---

const { TestWorld } = await import('../../src/interface/world/TestWorld.ts')
const { VariableNotFoundError } = await import('../../src/domain/errors/index.ts')

// --- Helpers ---

function createWorld(): InstanceType<typeof TestWorld> {
  return new TestWorld({ attach: mock(() => {}), parameters: {}, log: mock(() => {}) } as any)
}

// --- Tests ---

describe('TestWorld', () => {
  let world: InstanceType<typeof TestWorld>

  beforeEach(() => {
    world = createWorld()
  })

  test('constructor creates VariableService and InterpolationService', () => {
    // VariableService is functional (set/get works)
    world.setVariable('probe', 'ok')
    expect(world.getVariable<string>('probe')).toBe('ok')

    // InterpolationService is functional (interpolation works)
    const result = world.interpolate('${probe}')
    expect(result).toBe('ok')
  })

  test('setVariable delegates to VariableService.set', () => {
    world.setVariable('name', 'Alice')
    expect(world.getVariable<string>('name')).toBe('Alice')

    // Overwrite
    world.setVariable('name', 'Bob')
    expect(world.getVariable<string>('name')).toBe('Bob')
  })

  test('getVariable delegates to VariableService.get', () => {
    world.setVariable('count', 42)
    const value = world.getVariable<number>('count')
    expect(value).toBe(42)
  })

  test('getVariable throws VariableNotFoundError for missing variable', () => {
    expect(() => world.getVariable('nonexistent')).toThrow(VariableNotFoundError)
  })

  test('hasVariable returns true for existing variable', () => {
    world.setVariable('exists', true)
    expect(world.hasVariable('exists')).toBe(true)
  })

  test('hasVariable returns false for missing variable', () => {
    expect(world.hasVariable('missing')).toBe(false)
  })

  test('interpolate replaces variables in text', () => {
    world.setVariable('greeting', 'Hello')
    world.setVariable('target', 'World')
    const result = world.interpolate('${greeting}, ${target}!')
    expect(result).toBe('Hello, World!')
  })

  test('interpolate handles built-in variables (uuid, timestamp)', () => {
    const uuidResult = world.interpolate('${uuid}')
    expect(uuidResult).toMatch(/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/)

    const timestampResult = world.interpolate('${timestamp}')
    expect(Number(timestampResult)).toBeGreaterThan(0)
  })

  test('reset clears all variables', () => {
    world.setVariable('a', 1)
    world.setVariable('b', 2)
    expect(world.hasVariable('a')).toBe(true)
    expect(world.hasVariable('b')).toBe(true)

    world.reset()

    expect(world.hasVariable('a')).toBe(false)
    expect(world.hasVariable('b')).toBe(false)
  })

  test('adapters are assignable', () => {
    const mockHttp = { get: mock(() => {}) } as any
    const mockBrowser = { goto: mock(() => {}) } as any
    const mockCli = { run: mock(() => {}) } as any
    const mockGraph = { query: mock(() => {}) } as any
    const mockSecurity = { activeScan: mock(() => {}) } as any

    world.http = mockHttp
    world.browser = mockBrowser
    world.cli = mockCli
    world.graph = mockGraph
    world.security = mockSecurity

    expect(world.http).toBe(mockHttp)
    expect(world.browser).toBe(mockBrowser)
    expect(world.cli).toBe(mockCli)
    expect(world.graph).toBe(mockGraph)
    expect(world.security).toBe(mockSecurity)
  })

  test('hasAdapter checks return false when adapters not set', () => {
    expect(world.hasBrowser).toBe(false)
    expect(world.hasHttp).toBe(false)
    expect(world.hasCli).toBe(false)
    expect(world.hasGraph).toBe(false)
    expect(world.hasSecurity).toBe(false)
  })

  test('hasAdapter checks return true when adapters are set', () => {
    world.http = { get: mock(() => {}) } as any
    world.browser = { goto: mock(() => {}) } as any
    world.cli = { run: mock(() => {}) } as any
    world.graph = { query: mock(() => {}) } as any
    world.security = { activeScan: mock(() => {}) } as any

    expect(world.hasBrowser).toBe(true)
    expect(world.hasHttp).toBe(true)
    expect(world.hasCli).toBe(true)
    expect(world.hasGraph).toBe(true)
    expect(world.hasSecurity).toBe(true)
  })
})
