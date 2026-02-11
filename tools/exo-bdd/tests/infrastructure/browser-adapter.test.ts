import { test, expect, describe, beforeEach, mock } from 'bun:test'
import type { BrowserAdapterConfig } from '../../src/application/config/index.ts'

const mockPage = {
  goto: mock(() => Promise.resolve()),
  reload: mock(() => Promise.resolve()),
  goBack: mock(() => Promise.resolve()),
  goForward: mock(() => Promise.resolve()),
  click: mock(() => Promise.resolve()),
  dblclick: mock(() => Promise.resolve()),
  fill: mock(() => Promise.resolve()),
  selectOption: mock(() => Promise.resolve()),
  check: mock(() => Promise.resolve()),
  uncheck: mock(() => Promise.resolve()),
  hover: mock(() => Promise.resolve()),
  focus: mock(() => Promise.resolve()),
  setInputFiles: mock(() => Promise.resolve()),
  waitForSelector: mock(() => Promise.resolve()),
  waitForLoadState: mock(() => Promise.resolve()),
  waitForTimeout: mock(() => Promise.resolve()),
  url: mock(() => 'http://localhost:3000/dashboard'),
  title: mock(() => Promise.resolve('Test Page')),
  textContent: mock(() => Promise.resolve('Hello World')),
  getAttribute: mock(() => Promise.resolve('btn-primary')),
  isVisible: mock(() => Promise.resolve(true)),
  isEnabled: mock(() => Promise.resolve(true)),
  isChecked: mock(() => Promise.resolve(false)),
  screenshot: mock(() => Promise.resolve(Buffer.from('fake-screenshot'))),
  evaluate: mock(() => Promise.resolve()),
  keyboard: {
    press: mock(() => Promise.resolve()),
  },
  locator: mock(() => ({
    pressSequentially: mock(() => Promise.resolve()),
  })),
}

const mockContext = {
  newPage: mock(() => Promise.resolve(mockPage)),
  clearCookies: mock(() => Promise.resolve()),
  close: mock(() => Promise.resolve()),
}

const mockBrowser = {
  newContext: mock(() => Promise.resolve(mockContext)),
  close: mock(() => Promise.resolve()),
}

const mockLaunch = mock(() => Promise.resolve(mockBrowser))

mock.module('@playwright/test', () => ({
  chromium: {
    launch: mockLaunch,
  },
  request: {
    newContext: mock(() => Promise.resolve({})),
  },
  default: {},
}))

// Dynamic import AFTER mock.module
const { PlaywrightBrowserAdapter } = await import(
  '../../src/infrastructure/adapters/browser/PlaywrightBrowserAdapter.ts'
)

describe('PlaywrightBrowserAdapter', () => {
  const defaultConfig: BrowserAdapterConfig = {
    baseURL: 'http://localhost:3000',
    headless: true,
    viewport: { width: 1280, height: 720 },
  }

  let adapter: InstanceType<typeof PlaywrightBrowserAdapter>

  beforeEach(() => {
    // Reset all mocks
    for (const key of Object.keys(mockPage)) {
      const val = (mockPage as any)[key]
      if (typeof val === 'function' && val.mockClear) val.mockClear()
    }
    mockPage.keyboard.press.mockClear()
    mockContext.newPage.mockClear()
    mockContext.clearCookies.mockClear()
    mockContext.close.mockClear()
    mockBrowser.newContext.mockClear()
    mockBrowser.close.mockClear()
    mockLaunch.mockClear()

    adapter = new PlaywrightBrowserAdapter(defaultConfig)
  })

  test('initialize launches chromium with headless config', async () => {
    await adapter.initialize()

    expect(mockLaunch).toHaveBeenCalledTimes(1)
    expect(mockLaunch).toHaveBeenCalledWith({ headless: true })
  })

  test('initialize creates context with viewport', async () => {
    await adapter.initialize()

    expect(mockBrowser.newContext).toHaveBeenCalledTimes(1)
    expect(mockBrowser.newContext).toHaveBeenCalledWith(
      expect.objectContaining({
        viewport: { width: 1280, height: 720 },
      }),
    )
  })

  test('initialize creates context with baseURL', async () => {
    await adapter.initialize()

    expect(mockBrowser.newContext).toHaveBeenCalledWith(
      expect.objectContaining({
        baseURL: 'http://localhost:3000',
      }),
    )
  })

  test('goto navigates page to path', async () => {
    await adapter.initialize()
    await adapter.goto('/login')

    expect(mockPage.goto).toHaveBeenCalledTimes(1)
    expect(mockPage.goto).toHaveBeenCalledWith('/login')
  })

  test('reload calls page.reload', async () => {
    await adapter.initialize()
    await adapter.reload()

    expect(mockPage.reload).toHaveBeenCalledTimes(1)
  })

  test('goBack calls page.goBack', async () => {
    await adapter.initialize()
    await adapter.goBack()

    expect(mockPage.goBack).toHaveBeenCalledTimes(1)
  })

  test('click delegates to page.click', async () => {
    await adapter.initialize()
    await adapter.click('#submit-btn')

    expect(mockPage.click).toHaveBeenCalledTimes(1)
    expect(mockPage.click).toHaveBeenCalledWith('#submit-btn')
  })

  test('fill delegates to page.fill', async () => {
    await adapter.initialize()
    await adapter.fill('#email', 'user@test.com')

    expect(mockPage.fill).toHaveBeenCalledTimes(1)
    expect(mockPage.fill).toHaveBeenCalledWith('#email', 'user@test.com')
  })

  test('selectOption delegates to page.selectOption', async () => {
    await adapter.initialize()
    await adapter.selectOption('#country', 'US')

    expect(mockPage.selectOption).toHaveBeenCalledTimes(1)
    expect(mockPage.selectOption).toHaveBeenCalledWith('#country', 'US')
  })

  test('check delegates to page.check', async () => {
    await adapter.initialize()
    await adapter.check('#terms')

    expect(mockPage.check).toHaveBeenCalledTimes(1)
    expect(mockPage.check).toHaveBeenCalledWith('#terms')
  })

  test('waitForSelector delegates with options', async () => {
    await adapter.initialize()
    await adapter.waitForSelector('.modal', { timeout: 5000, state: 'visible' })

    expect(mockPage.waitForSelector).toHaveBeenCalledTimes(1)
    expect(mockPage.waitForSelector).toHaveBeenCalledWith('.modal', {
      timeout: 5000,
      state: 'visible',
    })
  })

  test('waitForNavigation waits for networkidle', async () => {
    await adapter.initialize()
    await adapter.waitForNavigation()

    expect(mockPage.waitForLoadState).toHaveBeenCalledTimes(1)
    expect(mockPage.waitForLoadState).toHaveBeenCalledWith('networkidle')
  })

  test('url returns current page URL', async () => {
    await adapter.initialize()
    const result = adapter.url()

    expect(result).toBe('http://localhost:3000/dashboard')
    expect(mockPage.url).toHaveBeenCalledTimes(1)
  })

  test('title returns page title', async () => {
    await adapter.initialize()
    const result = await adapter.title()

    expect(result).toBe('Test Page')
    expect(mockPage.title).toHaveBeenCalledTimes(1)
  })

  test('textContent returns element text', async () => {
    await adapter.initialize()
    const result = await adapter.textContent('.heading')

    expect(result).toBe('Hello World')
    expect(mockPage.textContent).toHaveBeenCalledTimes(1)
    expect(mockPage.textContent).toHaveBeenCalledWith('.heading')
  })

  test('isVisible returns visibility state', async () => {
    await adapter.initialize()
    const result = await adapter.isVisible('.banner')

    expect(result).toBe(true)
    expect(mockPage.isVisible).toHaveBeenCalledTimes(1)
    expect(mockPage.isVisible).toHaveBeenCalledWith('.banner')
  })

  test('screenshot returns Buffer', async () => {
    await adapter.initialize()
    const result = await adapter.screenshot({ fullPage: true, type: 'png' })

    expect(result).toBeInstanceOf(Buffer)
    expect(mockPage.screenshot).toHaveBeenCalledTimes(1)
    expect(mockPage.screenshot).toHaveBeenCalledWith(
      expect.objectContaining({ fullPage: true, type: 'png' }),
    )
  })

  test('clearContext clears cookies and localStorage', async () => {
    await adapter.initialize()
    await adapter.clearContext()

    expect(mockContext.clearCookies).toHaveBeenCalledTimes(1)
    expect(mockPage.evaluate).toHaveBeenCalledTimes(1)
    expect(mockPage.evaluate).toHaveBeenCalledWith(expect.any(Function))
  })

  test('dispose closes context and browser', async () => {
    await adapter.initialize()
    await adapter.dispose()

    expect(mockContext.close).toHaveBeenCalledTimes(1)
    expect(mockBrowser.close).toHaveBeenCalledTimes(1)
  })
})
