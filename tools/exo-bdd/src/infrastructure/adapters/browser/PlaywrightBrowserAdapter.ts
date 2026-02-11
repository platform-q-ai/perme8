import { chromium, type Browser, type BrowserContext, type Page } from '@playwright/test'
import type { BrowserPort, WaitOptions } from '../../../application/ports/index.ts'
import type { BrowserAdapterConfig } from '../../../application/config/index.ts'
import type { ScreenshotOptions } from '../../../domain/entities/index.ts'

export class PlaywrightBrowserAdapter implements BrowserPort {
  private browser!: Browser
  private context!: BrowserContext
  private _page?: Page

  constructor(readonly config: BrowserAdapterConfig) {}

  async initialize(): Promise<void> {
    this.browser = await chromium.launch({ headless: this.config.headless ?? true })
    this.context = await this.browser.newContext({
      viewport: this.config.viewport,
      baseURL: this.config.baseURL,
    })
    this._page = await this.context.newPage()
  }

  private guardPage(): Page {
    if (!this._page) {
      throw new Error('Browser not initialized. Call initialize() before accessing the page.')
    }
    return this._page
  }

  get page(): Page {
    return this.guardPage()
  }

  // Navigation
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

  // Interactions
  async click(selector: string): Promise<void> {
    await this.guardPage().click(selector)
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

  // File upload
  async uploadFile(selector: string, filePath: string): Promise<void> {
    await this.guardPage().setInputFiles(selector, filePath)
  }

  // Waiting
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

  // Information
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

  // Screenshots
  async screenshot(options?: ScreenshotOptions): Promise<Buffer> {
    return (await this.guardPage().screenshot({
      fullPage: options?.fullPage,
      clip: options?.clip,
      type: options?.type,
      quality: options?.quality,
      path: options?.path,
    })) as Buffer
  }

  // Context management
  async clearContext(): Promise<void> {
    await this.context.clearCookies()
    await this.guardPage().evaluate(() => localStorage.clear())
  }

  // Lifecycle
  async dispose(): Promise<void> {
    await this.context.close()
    await this.browser.close()
  }
}
