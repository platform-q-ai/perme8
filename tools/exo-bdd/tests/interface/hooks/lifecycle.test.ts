import { test, expect, describe, beforeEach, mock } from 'bun:test'

// --- Capture registered hooks ---

type HookFn = (...args: any[]) => any

let capturedBeforeAll: HookFn | null = null
let capturedBefore: HookFn | null = null
let capturedAfter: HookFn | null = null
let capturedAfterAll: HookFn | null = null
let capturedWorldConstructor: unknown = null

const mockSetWorldConstructor = mock((ctor: unknown) => {
  capturedWorldConstructor = ctor
})
const mockBeforeAll = mock((fn: HookFn) => {
  capturedBeforeAll = fn
})
const mockBefore = mock((fn: HookFn) => {
  capturedBefore = fn
})
const mockAfter = mock((fn: HookFn) => {
  capturedAfter = fn
})
const mockAfterAll = mock((fn: HookFn) => {
  capturedAfterAll = fn
})

mock.module('@cucumber/cucumber', () => ({
  BeforeAll: mockBeforeAll,
  AfterAll: mockAfterAll,
  Before: mockBefore,
  After: mockAfter,
  setWorldConstructor: mockSetWorldConstructor,
  Status: { FAILED: 'FAILED', PASSED: 'PASSED' },
  World: class FakeWorld {
    attach = mock(() => {})
    constructor(_options: unknown) {}
  },
}))

// --- Mock loadConfig and createAdapters ---

const mockConfig = { adapters: { http: { baseURL: 'http://localhost' } } }
const mockDispose = mock(() => Promise.resolve())

const mockAdapters = {
  http: { get: mock(() => {}) },
  browser: {
    screenshot: mock(() => Promise.resolve(Buffer.from('fake-png'))),
    clearContext: mock(() => Promise.resolve()),
  },
  cli: { run: mock(() => {}) },
  graph: { query: mock(() => {}) },
  security: { activeScan: mock(() => {}) },
  dispose: mockDispose,
}

const mockLoadConfig = mock(() => Promise.resolve(mockConfig))
const mockCreateAdapters = mock((): Promise<any> => Promise.resolve(mockAdapters))

// Mock using absolute paths so bun resolves them correctly regardless of importer
mock.module(
  `${import.meta.dir}/../../../src/application/config/index.ts`,
  () => ({
    loadConfig: mockLoadConfig,
    defineConfig: (c: any) => c,
  }),
)

mock.module(
  `${import.meta.dir}/../../../src/infrastructure/factories/index.ts`,
  () => ({
    createAdapters: mockCreateAdapters,
  }),
)

// --- Import the lifecycle module (triggers registration) ---

await import('../../../src/interface/hooks/lifecycle.ts')

const { TestWorld } = await import('../../../src/interface/world/TestWorld.ts')

// --- Tests ---

describe('Lifecycle hooks', () => {
  beforeEach(() => {
    mockLoadConfig.mockClear()
    mockCreateAdapters.mockClear()
    mockDispose.mockClear()
    mockAdapters.browser.screenshot.mockClear()
    mockAdapters.browser.clearContext.mockClear()
  })

  test('setWorldConstructor is called with TestWorld', () => {
    expect(mockSetWorldConstructor).toHaveBeenCalledTimes(1)
    expect(capturedWorldConstructor).toBe(TestWorld)
  })

  test('BeforeAll loads config and creates adapters', async () => {
    expect(capturedBeforeAll).not.toBeNull()
    await capturedBeforeAll!()

    expect(mockLoadConfig).toHaveBeenCalledTimes(1)
    expect(mockCreateAdapters).toHaveBeenCalledTimes(1)
    expect(mockCreateAdapters).toHaveBeenCalledWith(mockConfig)
  })

  test('Before attaches adapters to world instance', async () => {
    // Ensure BeforeAll has run to populate adapters
    await capturedBeforeAll!()

    const worldContext = {
      http: undefined as any,
      browser: undefined as any,
      cli: undefined as any,
      graph: undefined as any,
      security: undefined as any,
      reset: mock(() => {}),
    }

    await capturedBefore!.call(worldContext)

    expect(worldContext.http).toBe(mockAdapters.http)
    expect(worldContext.browser).toBe(mockAdapters.browser)
    expect(worldContext.cli).toBe(mockAdapters.cli)
    expect(worldContext.graph).toBe(mockAdapters.graph)
    expect(worldContext.security).toBe(mockAdapters.security)
  })

  test('Before calls world.reset()', async () => {
    await capturedBeforeAll!()

    const worldContext = {
      http: undefined as any,
      browser: undefined as any,
      cli: undefined as any,
      graph: undefined as any,
      security: undefined as any,
      reset: mock(() => {}),
    }

    await capturedBefore!.call(worldContext)

    expect(worldContext.reset).toHaveBeenCalledTimes(1)
  })

  test('Before skips undefined adapters', async () => {
    // Override createAdapters to return partial adapters
    const partialAdapters = {
      http: { get: mock(() => {}) },
      browser: undefined,
      cli: undefined,
      graph: undefined,
      security: undefined,
      dispose: mock(() => Promise.resolve()),
    }
    mockCreateAdapters.mockImplementationOnce(() => Promise.resolve(partialAdapters))
    await capturedBeforeAll!()

    const worldContext = {
      http: undefined as any,
      browser: 'original-browser' as any,
      cli: 'original-cli' as any,
      graph: 'original-graph' as any,
      security: 'original-security' as any,
      reset: mock(() => {}),
    }

    await capturedBefore!.call(worldContext)

    expect(worldContext.http).toBe(partialAdapters.http)
    // Undefined adapters should NOT overwrite existing world values
    expect(worldContext.browser).toBe('original-browser')
    expect(worldContext.cli).toBe('original-cli')
    expect(worldContext.graph).toBe('original-graph')
    expect(worldContext.security).toBe('original-security')
  })

  test('After captures screenshot on failure when browser available', async () => {
    // Ensure adapters are populated
    mockCreateAdapters.mockImplementationOnce(() => Promise.resolve(mockAdapters))
    await capturedBeforeAll!()

    const mockAttach = mock(() => {})
    const worldContext = {
      browser: mockAdapters.browser,
      hasBrowser: true,
      attach: mockAttach,
    }

    const scenario = { result: { status: 'FAILED' } }

    await capturedAfter!.call(worldContext, scenario)

    expect(mockAdapters.browser.screenshot).toHaveBeenCalledTimes(1)
    expect(mockAttach).toHaveBeenCalledWith(Buffer.from('fake-png'), 'image/png')
  })

  test('After does not capture screenshot when no browser', async () => {
    const mockAttach = mock(() => {})
    const worldContext = {
      browser: undefined as any,
      hasBrowser: false,
      attach: mockAttach,
    }

    const scenario = { result: { status: 'FAILED' } }

    await capturedAfter!.call(worldContext, scenario)

    expect(mockAttach).not.toHaveBeenCalled()
  })

  test('After does not capture screenshot on success', async () => {
    const mockAttach = mock(() => {})
    const worldContext = {
      browser: mockAdapters.browser,
      hasBrowser: true,
      attach: mockAttach,
    }

    const scenario = { result: { status: 'PASSED' } }

    await capturedAfter!.call(worldContext, scenario)

    expect(mockAdapters.browser.screenshot).not.toHaveBeenCalled()
    expect(mockAttach).not.toHaveBeenCalled()
  })

  test('After clears browser context', async () => {
    const worldContext = {
      browser: mockAdapters.browser,
      hasBrowser: true,
      attach: mock(() => {}),
    }

    const scenario = { result: { status: 'PASSED' } }

    await capturedAfter!.call(worldContext, scenario)

    expect(mockAdapters.browser.clearContext).toHaveBeenCalledTimes(1)
  })

  test('AfterAll disposes all adapters', async () => {
    // Ensure BeforeAll has run to set the module-level adapters
    mockCreateAdapters.mockImplementationOnce(() => Promise.resolve(mockAdapters))
    await capturedBeforeAll!()

    await capturedAfterAll!()

    expect(mockDispose).toHaveBeenCalledTimes(1)
  })

  test('AfterAll handles null adapters gracefully', async () => {
    // Create a fresh adapters ref with only dispose
    const nullableAdapters = { dispose: mock(() => Promise.resolve()) }
    mockCreateAdapters.mockImplementationOnce(() => Promise.resolve(nullableAdapters))
    await capturedBeforeAll!()

    // AfterAll should not throw even when adapters has no adapter ports
    await expect(capturedAfterAll!()).resolves.toBeUndefined()
  })
})
