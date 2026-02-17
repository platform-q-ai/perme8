import type { BrowserAdapterConfig } from '../config/ConfigSchema.ts'
import type { ScreenshotOptions } from '../../domain/entities/index.ts'
import type { Page } from '@playwright/test'

export interface WaitOptions {
  timeout?: number
  state?: 'attached' | 'detached' | 'visible' | 'hidden'
}

export interface BrowserPort {
  // Configuration
  readonly config: BrowserAdapterConfig

  // Page access
  readonly page: Page

  // Navigation
  goto(path: string): Promise<void>
  reload(): Promise<void>
  goBack(): Promise<void>
  goForward(): Promise<void>

  // Interactions
  click(selector: string): Promise<void>
  forceClick(selector: string): Promise<void>
  doubleClick(selector: string): Promise<void>
  fill(selector: string, value: string): Promise<void>
  clear(selector: string): Promise<void>
  selectOption(selector: string, value: string): Promise<void>
  check(selector: string): Promise<void>
  uncheck(selector: string): Promise<void>
  press(key: string): Promise<void>
  type(selector: string, text: string): Promise<void>
  hover(selector: string): Promise<void>
  focus(selector: string): Promise<void>

  // File upload
  uploadFile(selector: string, filePath: string): Promise<void>

  // Waiting
  waitForSelector(selector: string, options?: WaitOptions): Promise<void>
  waitForNavigation(): Promise<void>
  waitForLoadState(state?: 'load' | 'domcontentloaded' | 'networkidle'): Promise<void>
  waitForTimeout(ms: number): Promise<void>

  // Information
  url(): string
  title(): Promise<string>
  textContent(selector: string): Promise<string | null>
  getAttribute(selector: string, name: string): Promise<string | null>
  isVisible(selector: string): Promise<boolean>
  isEnabled(selector: string): Promise<boolean>
  isChecked(selector: string): Promise<boolean>

  // Screenshots
  screenshot(options?: ScreenshotOptions): Promise<Buffer>

  // Context management
  clearContext(): Promise<void>

  // Session management (multi-browser)
  createSession(name: string): Promise<void>
  switchTo(name: string): void
  readonly activeSessionName: string | null
  readonly sessionNames: string[]

  // Lifecycle
  dispose(): Promise<void>
}
