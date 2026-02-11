import { Given, When } from '@cucumber/cucumber'
import { TestWorld } from '../../world/index.ts'

// --- Context interface ---

export interface NavigationContext {
  browser: TestWorld['browser']
  interpolate: TestWorld['interpolate']
}

// --- Exported handler functions ---

export async function navigateTo(context: NavigationContext, path: string): Promise<void> {
  await context.browser.goto(context.interpolate(path))
}

export async function reloadPage(context: NavigationContext): Promise<void> {
  await context.browser.reload()
}

export async function goBack(context: NavigationContext): Promise<void> {
  await context.browser.goBack()
}

export async function goForward(context: NavigationContext): Promise<void> {
  await context.browser.goForward()
}

// --- Cucumber registrations ---

Given<TestWorld>('I am on {string}', async function (path: string) {
  await navigateTo(this, path)
})

Given<TestWorld>('I navigate to {string}', async function (path: string) {
  await navigateTo(this, path)
})

When<TestWorld>('I navigate to {string}', async function (path: string) {
  await navigateTo(this, path)
})

When<TestWorld>('I reload the page', async function () {
  await reloadPage(this)
})

When<TestWorld>('I go back', async function () {
  await goBack(this)
})

When<TestWorld>('I go forward', async function () {
  await goForward(this)
})
