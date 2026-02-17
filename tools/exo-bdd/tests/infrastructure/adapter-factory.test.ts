import { test, expect, describe, beforeEach, mock } from 'bun:test'
import type { ExoBddConfig } from '../../src/application/config/index.ts'

// --- Mock @playwright/test ---

const mockHttpContextDispose = mock(() => Promise.resolve())
const mockHttpContext = {
  fetch: mock(() =>
    Promise.resolve({
      status: () => 200,
      statusText: () => 'OK',
      headersArray: () => [],
      text: () => Promise.resolve('{}'),
    }),
  ),
  dispose: mockHttpContextDispose,
}

const mockNewContext = mock(() => Promise.resolve(mockHttpContext))

const mockBrowserPage = {
  goto: mock(() => Promise.resolve()),
}
const mockBrowserContext = {
  newPage: mock(() => Promise.resolve(mockBrowserPage)),
  close: mock(() => Promise.resolve()),
}
const mockBrowser = {
  newContext: mock(() => Promise.resolve(mockBrowserContext)),
  close: mock(() => Promise.resolve()),
}

const mockLaunch = mock(() => Promise.resolve(mockBrowser))

mock.module('@playwright/test', () => ({
  request: {
    newContext: mockNewContext,
  },
  chromium: {
    launch: mockLaunch,
  },
  default: {},
}))

// --- Mock neo4j-driver ---

const mockSessionClose = mock(() => Promise.resolve())
const mockDriverClose = mock(() => Promise.resolve())

const mockSession = {
  run: mock(() => Promise.resolve({ records: [] })),
  close: mockSessionClose,
}

const mockDriver = {
  session: mock(() => mockSession),
  close: mockDriverClose,
}

const mockNeo4jDriver = mock(() => mockDriver)
const mockBasicAuth = mock((user: string, pass: string) => ({ principal: user, credentials: pass }))

mock.module('neo4j-driver', () => ({
  default: {
    driver: mockNeo4jDriver,
    auth: {
      basic: mockBasicAuth,
    },
  },
}))

// --- Mock jsonpath (used by PlaywrightHttpAdapter) ---

mock.module('jsonpath', () => ({
  default: {
    query: () => [],
  },
}))

// --- Import after mocking ---

const { createAdapters } = await import(
  '../../src/infrastructure/factories/AdapterFactory.ts'
)

// --- Config helpers ---

const fullConfig: ExoBddConfig = {
  adapters: {
    http: {
      baseURL: 'https://api.example.com',
      timeout: 5000,
    },
    browser: {
      baseURL: 'https://app.example.com',
      headless: true,
    },
    cli: {
      workingDir: '/tmp',
    },
    graph: {
      uri: 'bolt://localhost:7687',
      username: 'neo4j',
      password: 's3cret',
    },
    security: {
      zapUrl: 'http://localhost:8080',
      zapApiKey: 'test-key',
    },
  },
}

const emptyConfig: ExoBddConfig = {
  adapters: {},
}

function configWith(adapter: keyof ExoBddConfig['adapters']): ExoBddConfig {
  return {
    adapters: {
      [adapter]: fullConfig.adapters[adapter],
    },
  }
}

// --- Tests ---

describe('AdapterFactory', () => {
  beforeEach(() => {
    mockHttpContext.dispose.mockClear()
    mockNewContext.mockClear()
    mockBrowserContext.close.mockClear()
    mockBrowser.close.mockClear()
    mockLaunch.mockClear()
    mockSessionClose.mockClear()
    mockDriverClose.mockClear()
    mockNeo4jDriver.mockClear()
  })

  test('createAdapters with full config creates all adapters', async () => {
    const adapters = await createAdapters(fullConfig)

    expect(adapters.http).toBeDefined()
    expect(adapters.browser).toBeDefined()
    expect(adapters.cli).toBeDefined()
    expect(adapters.graph).toBeDefined()
    expect(adapters.security).toBeDefined()

    await adapters.dispose()
  })

  test('createAdapters with empty config creates no adapters', async () => {
    const adapters = await createAdapters(emptyConfig)

    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeUndefined()
    expect(adapters.security).toBeUndefined()

    await adapters.dispose()
  })

  test('createAdapters with only HTTP config', async () => {
    const adapters = await createAdapters(configWith('http'))

    expect(adapters.http).toBeDefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeUndefined()
    expect(adapters.security).toBeUndefined()

    await adapters.dispose()
  })

  test('createAdapters with only browser config', async () => {
    const adapters = await createAdapters(configWith('browser'))

    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeDefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeUndefined()
    expect(adapters.security).toBeUndefined()

    await adapters.dispose()
  })

  test('createAdapters with only CLI config', async () => {
    const adapters = await createAdapters(configWith('cli'))

    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeDefined()
    expect(adapters.graph).toBeUndefined()
    expect(adapters.security).toBeUndefined()

    await adapters.dispose()
  })

  test('createAdapters with only graph config', async () => {
    const adapters = await createAdapters(configWith('graph'))

    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeDefined()
    expect(adapters.security).toBeUndefined()

    await adapters.dispose()
  })

  test('createAdapters with only security config', async () => {
    const adapters = await createAdapters(configWith('security'))

    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeUndefined()
    expect(adapters.security).toBeDefined()

    await adapters.dispose()
  })

  test('createAdapters calls initialize on HTTP adapter', async () => {
    const adapters = await createAdapters(configWith('http'))

    // PlaywrightHttpAdapter.initialize() calls request.newContext()
    expect(mockNewContext).toHaveBeenCalled()
    expect(adapters.http).toBeDefined()

    await adapters.dispose()
  })

  test('createAdapters calls initialize on browser adapter', async () => {
    const adapters = await createAdapters(configWith('browser'))

    // PlaywrightBrowserAdapter.initialize() calls chromium.launch()
    expect(mockLaunch).toHaveBeenCalled()
    expect(adapters.browser).toBeDefined()

    await adapters.dispose()
  })

  test('createAdapters calls connect on graph adapter', async () => {
    const adapters = await createAdapters(configWith('graph'))

    // Neo4jGraphAdapter.connect() calls neo4j.driver()
    expect(mockNeo4jDriver).toHaveBeenCalled()
    expect(adapters.graph).toBeDefined()

    await adapters.dispose()
  })

  test('dispose calls dispose on all created adapters', async () => {
    const adapters = await createAdapters(fullConfig)

    await adapters.dispose()

    // HTTP adapter: calls context.dispose()
    expect(mockHttpContext.dispose).toHaveBeenCalled()

    // Browser adapter: calls context.close() and browser.close()
    expect(mockBrowserContext.close).toHaveBeenCalled()
    expect(mockBrowser.close).toHaveBeenCalled()

    // Graph adapter: calls session.close() and driver.close()
    expect(mockSessionClose).toHaveBeenCalled()
    expect(mockDriverClose).toHaveBeenCalled()
  })

  test('dispose handles undefined adapters gracefully', async () => {
    const adapters = await createAdapters(configWith('http'))

    // browser, cli, graph, security are all undefined
    // dispose should not throw when calling ?.dispose() on them
    await expect(adapters.dispose()).resolves.toBeUndefined()

    expect(mockHttpContext.dispose).toHaveBeenCalled()
  })

  test('adapterFilter only creates the matching adapter', async () => {
    const adapters = await createAdapters(fullConfig, { adapterFilter: 'security' })

    expect(adapters.security).toBeDefined()
    expect(adapters.http).toBeUndefined()
    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()
    expect(adapters.graph).toBeUndefined()

    // browser.initialize (chromium.launch) should NOT have been called
    expect(mockLaunch).not.toHaveBeenCalled()

    await adapters.dispose()
  })

  test('adapterFilter with no matching config adapter creates nothing', async () => {
    // alkali-like config with only CLI
    const adapters = await createAdapters(configWith('cli'), { adapterFilter: 'browser' })

    expect(adapters.browser).toBeUndefined()
    expect(adapters.cli).toBeUndefined()

    await adapters.dispose()
  })

  test('no adapterFilter creates all configured adapters (backward compat)', async () => {
    const adapters = await createAdapters(fullConfig)

    expect(adapters.http).toBeDefined()
    expect(adapters.browser).toBeDefined()
    expect(adapters.cli).toBeDefined()
    expect(adapters.graph).toBeDefined()
    expect(adapters.security).toBeDefined()

    await adapters.dispose()
  })

  test('dispose calls all dispose in parallel', async () => {
    const disposeOrder: string[] = []
    let httpResolve!: () => void
    let graphResolve!: () => void

    // Replace mock implementations to track call ordering
    mockHttpContext.dispose.mockImplementationOnce(
      () =>
        new Promise<void>((resolve) => {
          httpResolve = () => {
            disposeOrder.push('http')
            resolve()
          }
        }),
    )

    mockSessionClose.mockImplementationOnce(
      () =>
        new Promise<void>((resolve) => {
          graphResolve = () => {
            disposeOrder.push('graph-session')
            resolve()
          }
        }),
    )
    mockDriverClose.mockImplementationOnce(() => {
      disposeOrder.push('graph-driver')
      return Promise.resolve()
    })

    const config: ExoBddConfig = {
      adapters: {
        http: fullConfig.adapters.http,
        graph: fullConfig.adapters.graph,
      },
    }
    const adapters = await createAdapters(config)
    const disposePromise = adapters.dispose()

    // Both dispose calls should be pending (started in parallel via Promise.all)
    // Resolve graph first, then http — if sequential, http would have to finish first
    graphResolve()
    await Promise.resolve() // flush microtask
    httpResolve()

    await disposePromise

    // Graph session resolved before http, proving parallel execution
    expect(disposeOrder[0]).toBe('graph-session')
    expect(disposeOrder).toContain('http')
  })
})
