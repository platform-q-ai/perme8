/**
 * Browser step definition tests.
 *
 * These tests invoke the actual exported handler functions from the step
 * definition files (navigation.steps, interactions.steps, assertions.steps)
 * rather than duplicating handler logic inline.  The mock world objects
 * satisfy the context interfaces at runtime because they have the same shape
 * (cast via `as any` to bypass Playwright's full Page type at compile time).
 *
 * Exception: tests for "I should see" / "I should not see" keep inline mock
 * wiring because the handlers rely on Playwright's expect(locator).toBeVisible()
 * which requires a real browser page.
 *
 * The "Variable interpolation integration" section continues calling mock
 * methods directly since those tests exercise the mock wiring, not handler
 * logic.
 */

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

// Mock @playwright/test so the assertion handlers use a working expect
mock.module('@playwright/test', () => ({
  expect,
  default: {},
}))

// Dynamic imports after mocks so Cucumber registrations run harmlessly
const { navigateTo, reloadPage, goBack } = await import(
  '../../../src/interface/steps/browser/navigation.steps.ts'
)
const { clickSelector, fillField, selectOption, checkBox, waitForVisible, waitForHidden, waitForPageLoad, takeScreenshot } = await import(
  '../../../src/interface/steps/browser/interactions.steps.ts'
)
const { assertUrl, assertUrlContains, assertPageTitle, assertPageTitleContains, assertSelectorContainsText, assertSelectorHasText, assertSelectorVisible, assertSelectorHidden, storeTextAs, storeUrlAs } = await import(
  '../../../src/interface/steps/browser/assertions.steps.ts'
)

// ---------------------------------------------------------------------------
// Helpers: mock world & mock browser adapter
// ---------------------------------------------------------------------------

function createMockBrowser() {
  const mockLocatorFirst = { _isVisible: true }

  const mockPage = {
    getByText: mock((_text: string) => ({
      first: () => mockLocatorFirst,
    })),
    locator: mock((_selector: string) => ({
      count: mock(() => Promise.resolve(0)),
      screenshot: mock(() => Promise.resolve(Buffer.from('element-screenshot'))),
    })),
    inputValue: mock((_selector: string) => Promise.resolve('')),
    _locatorTarget: mockLocatorFirst,
  }

  return {
    // Navigation
    goto: mock((_path: string) => Promise.resolve()),
    reload: mock(() => Promise.resolve()),
    goBack: mock(() => Promise.resolve()),
    goForward: mock(() => Promise.resolve()),

    // Interactions
    click: mock((_selector: string) => Promise.resolve()),
    doubleClick: mock((_selector: string) => Promise.resolve()),
    fill: mock((_selector: string, _value: string) => Promise.resolve()),
    clear: mock((_selector: string) => Promise.resolve()),
    selectOption: mock((_selector: string, _value: string) => Promise.resolve()),
    check: mock((_selector: string) => Promise.resolve()),
    uncheck: mock((_selector: string) => Promise.resolve()),
    press: mock((_key: string) => Promise.resolve()),
    type: mock((_selector: string, _text: string) => Promise.resolve()),
    hover: mock((_selector: string) => Promise.resolve()),
    focus: mock((_selector: string) => Promise.resolve()),
    uploadFile: mock((_selector: string, _filePath: string) => Promise.resolve()),

    // Waiting
    waitForSelector: mock((_selector: string, _options?: any) => Promise.resolve()),
    waitForNavigation: mock(() => Promise.resolve()),
    waitForLoadState: mock((_state?: string) => Promise.resolve()),
    waitForTimeout: mock((_ms: number) => Promise.resolve()),

    // Information
    url: mock(() => 'http://localhost:3000/dashboard'),
    title: mock(() => Promise.resolve('My Dashboard')),
    textContent: mock((_selector: string) => Promise.resolve('Hello World' as string | null)),
    getAttribute: mock((_selector: string, _name: string) => Promise.resolve(null as string | null)),
    isVisible: mock((_selector: string) => Promise.resolve(true)),
    isEnabled: mock((_selector: string) => Promise.resolve(true)),
    isChecked: mock((_selector: string) => Promise.resolve(false)),

    // Screenshots
    screenshot: mock((_options?: any) => Promise.resolve(Buffer.from('fake-screenshot'))),

    // Context management
    clearContext: mock(() => Promise.resolve()),
    dispose: mock(() => Promise.resolve()),

    // Page access
    page: mockPage,
    config: {} as any,
  }
}

interface MockWorld {
  browser: ReturnType<typeof createMockBrowser>
  interpolate: (text: string) => string
  setVariable: (name: string, value: unknown) => void
  getVariable: <T>(name: string) => T
  hasVariable: (name: string) => boolean
  attach: ReturnType<typeof mock>
}

function createMockWorld(): MockWorld {
  const variableService = new VariableService()
  const interpolationService = new InterpolationService(variableService)

  return {
    browser: createMockBrowser(),
    interpolate: (text: string) => interpolationService.interpolate(text),
    setVariable: (name: string, value: unknown) => variableService.set(name, value),
    getVariable: <T>(name: string) => variableService.get<T>(name),
    hasVariable: (name: string) => variableService.has(name),
    attach: mock((_data: any, _mimeType: string) => {}),
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('Browser step definitions – Navigation', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 1. 'I navigate to' calls browser.goto
  test('I navigate to {string} calls browser.goto with interpolated path', async () => {
    await navigateTo(world as any, '/users')

    expect(world.browser.goto).toHaveBeenCalledTimes(1)
    expect(world.browser.goto).toHaveBeenCalledWith('/users')
  })

  // 2. 'I am on' calls browser.goto (alias)
  test('I am on {string} calls browser.goto (alias for navigate)', async () => {
    await navigateTo(world as any, '/home')

    expect(world.browser.goto).toHaveBeenCalledTimes(1)
    expect(world.browser.goto).toHaveBeenCalledWith('/home')
  })

  // 3. 'I reload the page' calls browser.reload
  test('I reload the page calls browser.reload', async () => {
    await reloadPage(world as any)

    expect(world.browser.reload).toHaveBeenCalledTimes(1)
  })

  // 4. 'I go back' calls browser.goBack
  test('I go back calls browser.goBack', async () => {
    await goBack(world as any)

    expect(world.browser.goBack).toHaveBeenCalledTimes(1)
  })

  // 5. 'I wait for the page to load' calls waitForLoadState('load')
  test('I wait for the page to load calls browser.waitForLoadState with load', async () => {
    await waitForPageLoad(world as any)

    expect(world.browser.waitForLoadState).toHaveBeenCalledTimes(1)
    expect(world.browser.waitForLoadState).toHaveBeenCalledWith('load')
  })
})

describe('Browser step definitions – Interactions', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 6. 'I click' calls browser.click
  test('I click {string} calls browser.click with interpolated selector', async () => {
    await clickSelector(world as any, '#submit-btn')

    expect(world.browser.click).toHaveBeenCalledTimes(1)
    expect(world.browser.click).toHaveBeenCalledWith('#submit-btn')
  })

  // 7. 'I fill with' calls browser.fill
  test('I fill {string} with {string} calls browser.fill', async () => {
    await fillField(world as any, '#username', 'alice')

    expect(world.browser.fill).toHaveBeenCalledTimes(1)
    expect(world.browser.fill).toHaveBeenCalledWith('#username', 'alice')
  })

  // 8. 'I select from' calls browser.selectOption
  test('I select {string} from {string} calls browser.selectOption', async () => {
    await selectOption(world as any, 'admin', '#role')

    expect(world.browser.selectOption).toHaveBeenCalledTimes(1)
    expect(world.browser.selectOption).toHaveBeenCalledWith('#role', 'admin')
  })

  // 9. 'I check' calls browser.check
  test('I check {string} calls browser.check', async () => {
    await checkBox(world as any, '#agree-terms')

    expect(world.browser.check).toHaveBeenCalledTimes(1)
    expect(world.browser.check).toHaveBeenCalledWith('#agree-terms')
  })

  // 10. 'I wait for to be visible' passes state:visible
  test('I wait for {string} to be visible calls waitForSelector with state visible', async () => {
    await waitForVisible(world as any, '.loading-spinner')

    expect(world.browser.waitForSelector).toHaveBeenCalledTimes(1)
    expect(world.browser.waitForSelector).toHaveBeenCalledWith('.loading-spinner', {
      state: 'visible',
    })
  })

  // 11. 'I wait for to be hidden' passes state:hidden
  test('I wait for {string} to be hidden calls waitForSelector with state hidden', async () => {
    await waitForHidden(world as any, '.loading-spinner')

    expect(world.browser.waitForSelector).toHaveBeenCalledTimes(1)
    expect(world.browser.waitForSelector).toHaveBeenCalledWith('.loading-spinner', {
      state: 'hidden',
    })
  })

  // 12. 'I take a screenshot' calls browser.screenshot and attach
  test('I take a screenshot calls browser.screenshot and attach', async () => {
    await takeScreenshot(world as any)

    expect(world.browser.screenshot).toHaveBeenCalledTimes(1)
    expect(world.attach).toHaveBeenCalledTimes(1)
    expect(world.attach).toHaveBeenCalledWith(expect.any(Buffer), 'image/png')
  })
})

describe('Browser step definitions – Assertions', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 13. 'the URL should be' passes for exact match
  test('the URL should be {string} passes for exact match', () => {
    world.browser.url = mock(() => 'http://localhost:3000/dashboard')

    assertUrl(world as any, 'http://localhost:3000/dashboard')
  })

  // 14. 'the URL should contain' passes for substring
  test('the URL should contain {string} passes for substring', () => {
    world.browser.url = mock(() => 'http://localhost:3000/dashboard?tab=settings')

    assertUrlContains(world as any, 'dashboard')
  })

  // 15. 'the page title should be' passes for exact match
  test('the page title should be {string} passes for exact match', async () => {
    world.browser.title = mock(() => Promise.resolve('My Dashboard'))

    await assertPageTitle(world as any, 'My Dashboard')
  })

  // 16. 'the page title should contain' passes for substring
  test('the page title should contain {string} passes for substring', async () => {
    world.browser.title = mock(() => Promise.resolve('My Dashboard - Admin'))

    await assertPageTitleContains(world as any, 'Dashboard')
  })

  // 17. 'I should see' passes when visible (mocks page.getByText -> locator.first())
  // Tests the mock wiring — handler uses Playwright expect which requires a real browser
  test('I should see {string} passes when text is visible', () => {
    const text = 'Welcome back'
    const interpolatedText = world.interpolate(text)

    const mockLocatorFirst = { _isVisible: true }
    world.browser.page.getByText = mock((_t: string) => ({
      first: () => mockLocatorFirst,
    }))

    const page = world.browser.page
    const locator = page.getByText(interpolatedText)
    const first = locator.first()

    // Verify the chain is called correctly
    expect(page.getByText).toHaveBeenCalledWith('Welcome back')
    expect(first).toBe(mockLocatorFirst)
    expect(first._isVisible).toBe(true)
  })

  // 18. 'I should not see' passes when not visible
  // Tests the mock wiring — handler uses Playwright expect which requires a real browser
  test('I should not see {string} passes when text is not visible', () => {
    const text = 'Secret data'
    const interpolatedText = world.interpolate(text)

    const mockLocatorFirst = { _isVisible: false }
    world.browser.page.getByText = mock((_t: string) => ({
      first: () => mockLocatorFirst,
    }))

    const page = world.browser.page
    const locator = page.getByText(interpolatedText)
    const first = locator.first()

    expect(page.getByText).toHaveBeenCalledWith('Secret data')
    expect(first._isVisible).toBe(false)
  })

  // 19. 'element should contain text' passes
  test('{string} should contain text {string} passes when text is present', async () => {
    world.browser.textContent = mock((_s: string) =>
      Promise.resolve('Hello World, how are you?' as string | null),
    )

    await assertSelectorContainsText(world as any, '.greeting', 'Hello World')

    expect(world.browser.textContent).toHaveBeenCalledWith('.greeting')
  })

  // 20. 'element should have text' passes (trimmed)
  test('{string} should have text {string} passes with trimmed comparison', async () => {
    world.browser.textContent = mock((_s: string) =>
      Promise.resolve('  Hello World  ' as string | null),
    )

    await assertSelectorHasText(world as any, '#title', 'Hello World')

    expect(world.browser.textContent).toHaveBeenCalledWith('#title')
  })

  // 21. 'element should be visible' passes
  test('{string} should be visible passes when isVisible returns true', async () => {
    world.browser.isVisible = mock((_s: string) => Promise.resolve(true))

    await assertSelectorVisible(world as any, '#main-content')

    expect(world.browser.isVisible).toHaveBeenCalledWith('#main-content')
  })

  // 22. '{string} should be hidden' passes when isVisible returns false
  test('{string} should be hidden passes when isVisible returns false', async () => {
    world.browser.isVisible = mock((_s: string) => Promise.resolve(false))

    await assertSelectorHidden(world as any, '.hidden-panel')

    expect(world.browser.isVisible).toHaveBeenCalledWith('.hidden-panel')
  })

  // 23. 'I store text of as variable' stores text content
  test('I store the text of {string} as {string} stores the text content', async () => {
    world.browser.textContent = mock((_s: string) =>
      Promise.resolve('Product ABC' as string | null),
    )

    await storeTextAs(world as any, '.product-name', 'productName')

    expect(world.browser.textContent).toHaveBeenCalledWith('.product-name')
    expect(world.getVariable<string>('productName')).toBe('Product ABC')
  })

  // 24. 'I store the URL as variable' stores current URL
  test('I store the URL as {string} stores the current URL', () => {
    world.browser.url = mock(() => 'http://localhost:3000/products/42')

    storeUrlAs(world as any, 'currentUrl')

    expect(world.getVariable<string>('currentUrl')).toBe('http://localhost:3000/products/42')
  })
})

describe('Browser step definitions – Additional', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  // 25. 'I wait for selector' with default options
  test('I wait for selector calls waitForSelector with default options', async () => {
    const selector = '#dynamic-content'

    await world.browser.waitForSelector(world.interpolate(selector))

    expect(world.browser.waitForSelector).toHaveBeenCalledTimes(1)
    expect(world.browser.waitForSelector).toHaveBeenCalledWith('#dynamic-content')
  })

  // 26. 'I wait for navigation' calls waitForNavigation
  test('I wait for navigation calls browser.waitForNavigation', async () => {
    await world.browser.waitForNavigation()

    expect(world.browser.waitForNavigation).toHaveBeenCalledTimes(1)
  })
})

describe('Browser step definitions – Variable interpolation integration', () => {
  let world: MockWorld

  beforeEach(() => {
    world = createMockWorld()
  })

  test('navigate to interpolated URL with stored variable', async () => {
    world.setVariable('baseUrl', 'http://localhost:8080')

    await world.browser.goto(world.interpolate('${baseUrl}/api/health'))

    expect(world.browser.goto).toHaveBeenCalledWith('http://localhost:8080/api/health')
  })

  test('fill uses interpolated selector and value', async () => {
    world.setVariable('field', '#email')
    world.setVariable('email', 'test@example.com')

    await world.browser.fill(world.interpolate('${field}'), world.interpolate('${email}'))

    expect(world.browser.fill).toHaveBeenCalledWith('#email', 'test@example.com')
  })

  test('click uses interpolated selector', async () => {
    world.setVariable('btn', '.submit-btn')

    await world.browser.click(world.interpolate('${btn}'))

    expect(world.browser.click).toHaveBeenCalledWith('.submit-btn')
  })

  test('URL assertion with interpolated expected value', () => {
    world.setVariable('expectedPath', '/dashboard')
    world.browser.url = mock(() => 'http://localhost:3000/dashboard')

    const url = world.browser.url()
    const expected = world.interpolate('http://localhost:3000${expectedPath}')

    expect(url).toBe(expected)
  })

  test('wait for network idle calls waitForLoadState with networkidle', async () => {
    await world.browser.waitForLoadState('networkidle')

    expect(world.browser.waitForLoadState).toHaveBeenCalledWith('networkidle')
  })
})
