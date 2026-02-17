import { Then } from '@cucumber/cucumber'
import { expect } from '@playwright/test'
import { TestWorld } from '../../world/index.ts'

// --- Context interface ---

export interface AssertionContext {
  browser: TestWorld['browser']
  interpolate: TestWorld['interpolate']
  setVariable: TestWorld['setVariable']
}

// --- Exported handler functions ---

// Visibility Assertions
export async function assertTextVisible(context: AssertionContext, text: string): Promise<void> {
  const page = context.browser.page
  const locator = page.getByText(context.interpolate(text))
  await expect(locator.first()).toBeVisible()
}

export async function assertTextNotVisible(context: AssertionContext, text: string): Promise<void> {
  const page = context.browser.page
  const locator = page.getByText(context.interpolate(text))
  await expect(locator.first()).not.toBeVisible()
}

export async function assertSelectorVisible(context: AssertionContext, selector: string): Promise<void> {
  const visible = await context.browser.isVisible(context.interpolate(selector))
  expect(visible).toBe(true)
}

export async function assertSelectorHidden(context: AssertionContext, selector: string): Promise<void> {
  const visible = await context.browser.isVisible(context.interpolate(selector))
  expect(visible).toBe(false)
}

export async function assertSelectorExists(context: AssertionContext, selector: string): Promise<void> {
  const count = await context.browser.page.locator(context.interpolate(selector)).count()
  expect(count).toBeGreaterThan(0)
}

export async function assertSelectorNotExists(context: AssertionContext, selector: string): Promise<void> {
  const count = await context.browser.page.locator(context.interpolate(selector)).count()
  expect(count).toBe(0)
}

// State Assertions
export async function assertSelectorEnabled(context: AssertionContext, selector: string): Promise<void> {
  const enabled = await context.browser.isEnabled(context.interpolate(selector))
  expect(enabled).toBe(true)
}

export async function assertSelectorDisabled(context: AssertionContext, selector: string): Promise<void> {
  const enabled = await context.browser.isEnabled(context.interpolate(selector))
  expect(enabled).toBe(false)
}

export async function assertSelectorChecked(context: AssertionContext, selector: string): Promise<void> {
  const checked = await context.browser.isChecked(context.interpolate(selector))
  expect(checked).toBe(true)
}

export async function assertSelectorNotChecked(context: AssertionContext, selector: string): Promise<void> {
  const checked = await context.browser.isChecked(context.interpolate(selector))
  expect(checked).toBe(false)
}

// Content Assertions
export async function assertSelectorHasText(context: AssertionContext, selector: string, expectedText: string): Promise<void> {
  const text = await context.browser.textContent(context.interpolate(selector))
  expect(text?.trim()).toBe(context.interpolate(expectedText))
}

export async function assertSelectorContainsText(context: AssertionContext, selector: string, expectedText: string): Promise<void> {
  const text = await context.browser.textContent(context.interpolate(selector))
  expect(text).toContain(context.interpolate(expectedText))
}

export async function assertSelectorHasValue(context: AssertionContext, selector: string, expectedValue: string): Promise<void> {
  const value = await context.browser.page.inputValue(context.interpolate(selector))
  expect(value).toBe(context.interpolate(expectedValue))
}

export async function assertSelectorHasAttribute(
  context: AssertionContext,
  selector: string,
  attrName: string,
  expectedValue: string,
): Promise<void> {
  const value = await context.browser.getAttribute(context.interpolate(selector), attrName)
  expect(value).toBe(context.interpolate(expectedValue))
}

export async function assertSelectorHasClass(context: AssertionContext, selector: string, className: string): Promise<void> {
  const classAttr = await context.browser.getAttribute(context.interpolate(selector), 'class')
  expect(classAttr).toContain(context.interpolate(className))
}

// Page Assertions
export async function assertPageTitle(context: AssertionContext, expectedTitle: string): Promise<void> {
  const title = await context.browser.title()
  expect(title).toBe(context.interpolate(expectedTitle))
}

export async function assertPageTitleContains(context: AssertionContext, expectedPart: string): Promise<void> {
  const title = await context.browser.title()
  expect(title).toContain(context.interpolate(expectedPart))
}

export function assertUrl(context: AssertionContext, expectedUrl: string): void {
  expect(context.browser.url()).toBe(context.interpolate(expectedUrl))
}

export async function assertUrlContains(context: AssertionContext, expectedPart: string): Promise<void> {
  const interpolated = context.interpolate(expectedPart)
  await context.browser.page.waitForURL(`**/*${interpolated}*`, { timeout: 5000 }).catch(() => {
    // If waitForURL times out, fall back to a direct assertion for a clear error message
    expect(context.browser.url()).toContain(interpolated)
  })
}

// Count Assertions
export async function assertElementCount(context: AssertionContext, count: number, selector: string): Promise<void> {
  const actual = await context.browser.page.locator(context.interpolate(selector)).count()
  expect(actual).toBe(count)
}

// Variable Storage
export async function storeTextAs(context: AssertionContext, selector: string, variableName: string): Promise<void> {
  const text = await context.browser.textContent(context.interpolate(selector))
  context.setVariable(variableName, text)
}

export async function storeValueAs(context: AssertionContext, selector: string, variableName: string): Promise<void> {
  const value = await context.browser.page.inputValue(context.interpolate(selector))
  context.setVariable(variableName, value)
}

export function storeUrlAs(context: AssertionContext, variableName: string): void {
  context.setVariable(variableName, context.browser.url())
}

// --- Cucumber registrations ---

// Visibility Assertions
Then<TestWorld>('I should see {string}', async function (text: string) {
  await assertTextVisible(this, text)
})

Then<TestWorld>('I should not see {string}', async function (text: string) {
  await assertTextNotVisible(this, text)
})

Then<TestWorld>('{string} should be visible', async function (selector: string) {
  await assertSelectorVisible(this, selector)
})

Then<TestWorld>('{string} should be hidden', async function (selector: string) {
  await assertSelectorHidden(this, selector)
})

Then<TestWorld>('{string} should exist', async function (selector: string) {
  await assertSelectorExists(this, selector)
})

Then<TestWorld>('{string} should not exist', async function (selector: string) {
  await assertSelectorNotExists(this, selector)
})

// State Assertions
Then<TestWorld>('{string} should be enabled', async function (selector: string) {
  await assertSelectorEnabled(this, selector)
})

Then<TestWorld>('{string} should be disabled', async function (selector: string) {
  await assertSelectorDisabled(this, selector)
})

Then<TestWorld>('{string} should be checked', async function (selector: string) {
  await assertSelectorChecked(this, selector)
})

Then<TestWorld>('{string} should not be checked', async function (selector: string) {
  await assertSelectorNotChecked(this, selector)
})

// Content Assertions
Then<TestWorld>('{string} should have text {string}', async function (selector: string, expectedText: string) {
  await assertSelectorHasText(this, selector, expectedText)
})

Then<TestWorld>('{string} should contain text {string}', async function (selector: string, expectedText: string) {
  await assertSelectorContainsText(this, selector, expectedText)
})

Then<TestWorld>('{string} should have value {string}', async function (selector: string, expectedValue: string) {
  await assertSelectorHasValue(this, selector, expectedValue)
})

Then<TestWorld>(
  '{string} should have attribute {string} with value {string}',
  async function (selector: string, attrName: string, expectedValue: string) {
    await assertSelectorHasAttribute(this, selector, attrName, expectedValue)
  },
)

Then<TestWorld>('{string} should have class {string}', async function (selector: string, className: string) {
  await assertSelectorHasClass(this, selector, className)
})

// Page Assertions
Then<TestWorld>('the page title should be {string}', async function (expectedTitle: string) {
  await assertPageTitle(this, expectedTitle)
})

Then<TestWorld>('the page title should contain {string}', async function (expectedPart: string) {
  await assertPageTitleContains(this, expectedPart)
})

Then<TestWorld>('the URL should be {string}', function (expectedUrl: string) {
  assertUrl(this, expectedUrl)
})

Then<TestWorld>('the URL should contain {string}', async function (expectedPart: string) {
  await assertUrlContains(this, expectedPart)
})

// Count Assertions
Then<TestWorld>('there should be {int} {string} elements', async function (count: number, selector: string) {
  await assertElementCount(this, count, selector)
})

// Variable Storage
Then<TestWorld>('I store the text of {string} as {string}', async function (selector: string, variableName: string) {
  await storeTextAs(this, selector, variableName)
})

Then<TestWorld>('I store the value of {string} as {string}', async function (selector: string, variableName: string) {
  await storeValueAs(this, selector, variableName)
})

Then<TestWorld>('I store the URL as {string}', function (variableName: string) {
  storeUrlAs(this, variableName)
})
