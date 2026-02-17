import { chromium, type Browser, type BrowserContext, type Page } from '@playwright/test'
import type { BrowserPort, WaitOptions } from '../../../application/ports/index.ts'
import type { BrowserAdapterConfig } from '../../../application/config/index.ts'
import type { ScreenshotOptions } from '../../../domain/entities/index.ts'

interface BrowserSession {
  context: BrowserContext
  page: Page
}

export class PlaywrightBrowserAdapter implements BrowserPort {
  private browser!: Browser
  private defaultContext!: BrowserContext
  private defaultPage?: Page

  // Named sessions for multi-browser scenarios
  private sessions = new Map<string, BrowserSession>()
  private _activeSessionName: string | null = null

  constructor(readonly config: BrowserAdapterConfig) {}

  async initialize(): Promise<void> {
    this.browser = await chromium.launch({ headless: this.config.headless ?? true })
    this.defaultContext = await this.browser.newContext({
      viewport: this.config.viewport,
      baseURL: this.config.baseURL,
    })
    this.defaultPage = await this.defaultContext.newPage()
  }

  private guardPage(): Page {
    // If a named session is active, use its page
    if (this._activeSessionName) {
      const session = this.sessions.get(this._activeSessionName)
      if (!session) {
        throw new Error(`Browser session "${this._activeSessionName}" not found.`)
      }
      return session.page
    }
    // Otherwise use the default page
    if (!this.defaultPage) {
      throw new Error('Browser not initialized. Call initialize() before accessing the page.')
    }
    return this.defaultPage
  }

  get page(): Page {
    return this.guardPage()
  }

  // --- Session management (multi-browser) ---

  get activeSessionName(): string | null {
    return this._activeSessionName
  }

  get sessionNames(): string[] {
    return Array.from(this.sessions.keys())
  }

  async createSession(name: string): Promise<void> {
    if (this.sessions.has(name)) {
      throw new Error(`Browser session "${name}" already exists.`)
    }
    const context = await this.browser.newContext({
      viewport: this.config.viewport,
      baseURL: this.config.baseURL,
    })
    const page = await context.newPage()
    this.sessions.set(name, { context, page })
    this._activeSessionName = name
  }

  switchTo(name: string): void {
    if (!this.sessions.has(name)) {
      throw new Error(`Browser session "${name}" does not exist. Create it first with createSession().`)
    }
    this._activeSessionName = name
  }

  private async clearSession(session: BrowserSession): Promise<void> {
    await session.context.clearCookies()
    try {
      await session.page.evaluate(() => localStorage.clear())
    } catch {
      // localStorage may not be accessible on about:blank or error pages
    }
    await session.page.goto('about:blank')
  }

  private async disposeSession(session: BrowserSession): Promise<void> {
    await session.context.close()
  }

  // --- Navigation ---

  async goto(path: string): Promise<void> {
    await this.guardPage().goto(path)
  }

  async reload(): Promise<void> {
    await this.guardPage().reload()
  }

  async goBack(): Promise<void> {
    await this.guardPage().goBack()
  }

  async goForward(): Promise<void> {
    await this.guardPage().goForward()
  }

  // --- Interactions ---

  async click(selector: string): Promise<void> {
    await this.guardPage().click(selector)
  }

  async forceClick(selector: string): Promise<void> {
    await this.guardPage().click(selector, { force: true })
  }

  async doubleClick(selector: string): Promise<void> {
    await this.guardPage().dblclick(selector)
  }

  async fill(selector: string, value: string): Promise<void> {
    await this.guardPage().fill(selector, value)
  }

  async clear(selector: string): Promise<void> {
    await this.guardPage().fill(selector, '')
  }

  async selectOption(selector: string, value: string): Promise<void> {
    await this.guardPage().selectOption(selector, value)
  }

  async check(selector: string): Promise<void> {
    await this.guardPage().check(selector)
  }

  async uncheck(selector: string): Promise<void> {
    await this.guardPage().uncheck(selector)
  }

  async press(key: string): Promise<void> {
    await this.guardPage().keyboard.press(key)
  }

  async type(selector: string, text: string): Promise<void> {
    await this.guardPage().locator(selector).pressSequentially(text)
  }

  async hover(selector: string): Promise<void> {
    await this.guardPage().hover(selector)
  }

  async focus(selector: string): Promise<void> {
    await this.guardPage().focus(selector)
  }

  // --- File upload ---

  async uploadFile(selector: string, filePath: string): Promise<void> {
    await this.guardPage().setInputFiles(selector, filePath)
  }

  // --- Waiting ---

  async waitForSelector(selector: string, options?: WaitOptions): Promise<void> {
    await this.guardPage().waitForSelector(selector, {
      timeout: options?.timeout,
      state: options?.state,
    })
  }

  async waitForNavigation(): Promise<void> {
    await this.guardPage().waitForLoadState('networkidle')
  }

  async waitForLoadState(state?: 'load' | 'domcontentloaded' | 'networkidle'): Promise<void> {
    await this.guardPage().waitForLoadState(state ?? 'load')
  }

  async waitForTimeout(ms: number): Promise<void> {
    await this.guardPage().waitForTimeout(ms)
  }

  // --- Information ---

  url(): string {
    return this.guardPage().url()
  }

  async title(): Promise<string> {
    return await this.guardPage().title()
  }

  async textContent(selector: string): Promise<string | null> {
    return await this.guardPage().textContent(selector)
  }

  async getAttribute(selector: string, name: string): Promise<string | null> {
    return await this.guardPage().getAttribute(selector, name)
  }

  async isVisible(selector: string): Promise<boolean> {
    return await this.guardPage().isVisible(selector)
  }

  async isEnabled(selector: string): Promise<boolean> {
    return await this.guardPage().isEnabled(selector)
  }

  async isChecked(selector: string): Promise<boolean> {
    return await this.guardPage().isChecked(selector)
  }

  // --- Screenshots ---

  async screenshot(options?: ScreenshotOptions): Promise<Buffer> {
    return (await this.guardPage().screenshot({
      fullPage: options?.fullPage,
      clip: options?.clip,
      type: options?.type,
      quality: options?.quality,
      path: options?.path,
    })) as Buffer
  }

  // --- Context management ---

  async clearContext(): Promise<void> {
    // Clear all named sessions
    for (const session of this.sessions.values()) {
      await this.clearSession(session)
    }
    for (const session of this.sessions.values()) {
      await this.disposeSession(session)
    }
    this.sessions.clear()
    this._activeSessionName = null

    // Clear default context
    await this.defaultContext.clearCookies()
    try {
      await this.guardPage().evaluate(() => localStorage.clear())
    } catch {
      // localStorage may not be accessible on about:blank or error pages
    }
    // Navigate to about:blank to kill any active WebSocket connections
    // (e.g., Phoenix LiveView sockets from previous scenarios)
    await this.guardPage().goto('about:blank')
  }

  // --- Lifecycle ---

  async dispose(): Promise<void> {
    // Dispose named sessions
    for (const session of this.sessions.values()) {
      await this.disposeSession(session)
    }
    this.sessions.clear()
    this._activeSessionName = null

    // Dispose default
    await this.defaultContext.close()
    await this.browser.close()
  }
}
