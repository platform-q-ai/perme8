import { Given, When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

// --- Context interface ---

export interface SessionContext {
  browser: TestWorld['browser']
}

// --- Exported handler functions ---

/**
 * Creates a new named browser session with its own BrowserContext and Page.
 * Each session has independent cookies, localStorage, and WebSocket connections,
 * enabling true multi-user testing (e.g., two users logged in simultaneously).
 *
 * After creation, the new session becomes the active session — all subsequent
 * browser steps (click, type, assert, etc.) operate on it until switchTo is called.
 */
export async function openBrowserSession(context: SessionContext, name: string): Promise<void> {
  await context.browser.createSession(name)
}

/**
 * Switches the active browser session. All subsequent browser steps will operate
 * on the named session's page until another switchTo call.
 */
export function switchToBrowserSession(context: SessionContext, name: string): void {
  context.browser.switchTo(name)
}

// --- Cucumber registrations ---

Given<TestWorld>('I open browser session {string}', async function (name: string) {
  await openBrowserSession(this, name)
})

When<TestWorld>('I switch to browser session {string}', function (name: string) {
  switchToBrowserSession(this, name)
})
