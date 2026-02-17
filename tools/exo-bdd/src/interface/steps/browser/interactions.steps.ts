import { When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

// --- Context interface ---

export interface InteractionContext {
  browser: TestWorld['browser']
  interpolate: TestWorld['interpolate']
  attach: TestWorld['attach']
}

// --- Exported handler functions ---

// Clicking
export async function clickSelector(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.click(context.interpolate(selector))
}

export async function forceClickSelector(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.forceClick(context.interpolate(selector))
}

export async function jsClick(context: InteractionContext, selector: string): Promise<void> {
  const interpolated = context.interpolate(selector)
  await context.browser.page.locator(interpolated).first().evaluate((el: HTMLElement) => el.click())
}

export async function clickButton(context: InteractionContext, text: string): Promise<void> {
  await context.browser.click(`button:has-text("${context.interpolate(text)}")`)
}

export async function clickLink(context: InteractionContext, text: string): Promise<void> {
  await context.browser.click(`a:has-text("${context.interpolate(text)}")`)
}

export async function clickElement(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.click(context.interpolate(selector))
}

export async function clickButtonAndNavigate(context: InteractionContext, text: string): Promise<void> {
  const page = context.browser.page
  const navigationPromise = page.waitForNavigation()
  await page.click(`button:has-text("${context.interpolate(text)}")`)
  await navigationPromise
}

export async function clickLinkAndNavigate(context: InteractionContext, text: string): Promise<void> {
  const page = context.browser.page
  const navigationPromise = page.waitForNavigation()
  await page.click(`a:has-text("${context.interpolate(text)}")`)
  await navigationPromise
}

export async function clickAtPosition(context: InteractionContext, selector: string, x: number, y: number): Promise<void> {
  await context.browser.page.locator(context.interpolate(selector)).first().click({ position: { x, y } })
}

export async function doubleClickSelector(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.doubleClick(context.interpolate(selector))
}

// Form Inputs
export async function fillField(context: InteractionContext, selector: string, value: string): Promise<void> {
  await context.browser.fill(context.interpolate(selector), context.interpolate(value))
}

export async function clearField(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.clear(context.interpolate(selector))
}

export async function typeIntoField(context: InteractionContext, text: string, selector: string): Promise<void> {
  await context.browser.type(context.interpolate(selector), context.interpolate(text))
}

export async function selectOption(context: InteractionContext, value: string, selector: string): Promise<void> {
  await context.browser.selectOption(context.interpolate(selector), context.interpolate(value))
}

export async function checkBox(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.check(context.interpolate(selector))
}

export async function uncheckBox(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.uncheck(context.interpolate(selector))
}

export async function pressKey(context: InteractionContext, key: string): Promise<void> {
  await context.browser.press(key)
}

export async function uploadFile(context: InteractionContext, filePath: string, selector: string): Promise<void> {
  await context.browser.uploadFile(context.interpolate(selector), context.interpolate(filePath))
}

// Browser Dialogs (confirm/alert/prompt)
export async function acceptNextDialog(context: InteractionContext): Promise<void> {
  context.browser.page.once('dialog', (dialog) => dialog.accept())
}

export async function dismissNextDialog(context: InteractionContext): Promise<void> {
  context.browser.page.once('dialog', (dialog) => dialog.dismiss())
}

// Hovering/Focus
export async function hoverOver(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.hover(context.interpolate(selector))
}

export async function focusOn(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.focus(context.interpolate(selector))
}

// Waiting
export async function waitForVisible(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.waitForSelector(context.interpolate(selector), { state: 'visible' })
}

export async function waitForHidden(context: InteractionContext, selector: string): Promise<void> {
  await context.browser.waitForSelector(context.interpolate(selector), { state: 'hidden' })
}

export async function waitForSeconds(context: InteractionContext, seconds: number): Promise<void> {
  await context.browser.waitForTimeout(seconds * 1000)
}

export async function waitForPageLoad(context: InteractionContext): Promise<void> {
  await context.browser.waitForLoadState('load')
}

export async function waitForNetworkIdle(context: InteractionContext): Promise<void> {
  await context.browser.waitForLoadState('networkidle')
}

// Screenshots
export async function takeScreenshot(context: InteractionContext): Promise<void> {
  const screenshot = await context.browser.screenshot()
  context.attach(screenshot, 'image/png')
}

export async function takeElementScreenshot(context: InteractionContext, selector: string): Promise<void> {
  const element = context.browser.page.locator(context.interpolate(selector))
  const screenshot = await element.screenshot()
  context.attach(screenshot, 'image/png')
}

// --- Cucumber registrations ---

// Clicking
When<TestWorld>('I click {string}', async function (selector: string) {
  await clickSelector(this, selector)
})

When<TestWorld>('I force click {string}', async function (selector: string) {
  await forceClickSelector(this, selector)
})

When<TestWorld>('I js click {string}', async function (selector: string) {
  await jsClick(this, selector)
})

When<TestWorld>('I click the {string} button', async function (text: string) {
  await clickButton(this, text)
})

When<TestWorld>('I click the {string} link', async function (text: string) {
  await clickLink(this, text)
})

When<TestWorld>('I click the {string} element', async function (selector: string) {
  await clickElement(this, selector)
})

When<TestWorld>('I click the {string} button and wait for navigation', async function (text: string) {
  await clickButtonAndNavigate(this, text)
})

When<TestWorld>('I click the {string} link and wait for navigation', async function (text: string) {
  await clickLinkAndNavigate(this, text)
})

When<TestWorld>('I click {string} at position {int},{int}', async function (selector: string, x: number, y: number) {
  await clickAtPosition(this, selector, x, y)
})

When<TestWorld>('I double-click {string}', async function (selector: string) {
  await doubleClickSelector(this, selector)
})

// Form Inputs
When<TestWorld>('I fill {string} with {string}', async function (selector: string, value: string) {
  await fillField(this, selector, value)
})

When<TestWorld>('I clear {string}', async function (selector: string) {
  await clearField(this, selector)
})

When<TestWorld>('I type {string} into {string}', async function (text: string, selector: string) {
  await typeIntoField(this, text, selector)
})

When<TestWorld>('I select {string} from {string}', async function (value: string, selector: string) {
  await selectOption(this, value, selector)
})

When<TestWorld>('I check {string}', async function (selector: string) {
  await checkBox(this, selector)
})

When<TestWorld>('I uncheck {string}', async function (selector: string) {
  await uncheckBox(this, selector)
})

When<TestWorld>('I press {string}', async function (key: string) {
  await pressKey(this, key)
})

When<TestWorld>('I upload {string} to {string}', async function (filePath: string, selector: string) {
  await uploadFile(this, filePath, selector)
})

// Browser Dialogs
When<TestWorld>('I accept the next browser dialog', async function () {
  await acceptNextDialog(this)
})

When<TestWorld>('I dismiss the next browser dialog', async function () {
  await dismissNextDialog(this)
})

// Hovering/Focus
When<TestWorld>('I hover over {string}', async function (selector: string) {
  await hoverOver(this, selector)
})

When<TestWorld>('I focus on {string}', async function (selector: string) {
  await focusOn(this, selector)
})

// Waiting
When<TestWorld>('I wait for {string} to be visible', async function (selector: string) {
  await waitForVisible(this, selector)
})

When<TestWorld>('I wait for {string} to be hidden', async function (selector: string) {
  await waitForHidden(this, selector)
})

When<TestWorld>('I wait for {int} seconds', async function (seconds: number) {
  await waitForSeconds(this, seconds)
})

When<TestWorld>('I wait for the page to load', async function () {
  await waitForPageLoad(this)
})

When<TestWorld>('I wait for network idle', async function () {
  await waitForNetworkIdle(this)
})

// Screenshots
When<TestWorld>('I take a screenshot', async function () {
  await takeScreenshot(this)
})

When<TestWorld>('I take a screenshot of {string}', async function (selector: string) {
  await takeElementScreenshot(this, selector)
})
