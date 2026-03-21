import { Given, Then, When } from '@cucumber/cucumber'
import { expect } from '@playwright/test'

import { TestWorld } from '../../world/index.ts'

Given<TestWorld>('browser notifications are allowed for the site', async function () {
  await this.browser.page.context().grantPermissions(['notifications'])

  await this.browser.page.addInitScript(() => {
    ;(window as typeof window & { __agentsLastNotification?: { title: string; body: string; tag: string } }).__agentsLastNotification = undefined

    class FakeNotification {
      static permission = 'granted'

      title: string
      body: string
      tag: string
      onclick: (() => void) | null = null

      constructor(title: string, options?: NotificationOptions) {
        this.title = title
        this.body = options?.body ?? ''
        this.tag = options?.tag ?? ''

        ;(window as typeof window & { __agentsLastNotification?: { title: string; body: string; tag: string } }).__agentsLastNotification = {
          title,
          body: this.body,
          tag: this.tag,
        }
      }

      static requestPermission() {
        return Promise.resolve('granted' as NotificationPermission)
      }

      close() {
        return undefined
      }
    }

    Object.defineProperty(window, 'Notification', {
      configurable: true,
      writable: true,
      value: FakeNotification,
    })
  })

  await this.browser.page.reload()
  await this.browser.waitForLoadState('networkidle')
})

When<TestWorld>('the sessions tab is in the background', async function () {
  await this.browser.page.evaluate(() => {
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'hidden',
    })

    document.dispatchEvent(new Event('visibilitychange'))
  })
})

When<TestWorld>('a running session completes for the current user', async function () {
  await this.browser.page.evaluate(() => {
    const hook = (window as typeof window & { __agentsBrowserNotificationsHook?: { showBrowserNotification: (payload: unknown) => void } }).__agentsBrowserNotificationsHook

    hook?.showBrowserNotification({
      title: 'Session completed',
      body: 'One of your sessions completed. Open Sessions to review it.',
      type: 'session_completed',
    })
  })
})

When<TestWorld>('a running session fails for the current user with an error message', async function () {
  await this.browser.page.evaluate(() => {
    const hook = (window as typeof window & { __agentsBrowserNotificationsHook?: { showBrowserNotification: (payload: unknown) => void } }).__agentsBrowserNotificationsHook

    hook?.showBrowserNotification({
      title: 'Session failed',
      body: 'One of your sessions failed. Open Sessions to review details.',
      type: 'session_failed',
    })
  })
})

Then<TestWorld>('a browser notification should be shown with the session outcome', async function () {
  const notification = await this.browser.page.evaluate(() => {
    return (window as typeof window & { __agentsLastNotification?: { title: string; body: string; tag: string } }).__agentsLastNotification ?? null
  })

  expect(notification).toEqual({
    title: 'Session completed',
    body: 'One of your sessions completed. Open Sessions to review it.',
    tag: 'session_completed',
  })
})

Then<TestWorld>('a browser notification should be shown with the failure message', async function () {
  const notification = await this.browser.page.evaluate(() => {
    return (window as typeof window & { __agentsLastNotification?: { title: string; body: string; tag: string } }).__agentsLastNotification ?? null
  })

  expect(notification).toEqual({
    title: 'Session failed',
    body: 'One of your sessions failed. Open Sessions to review details.',
    tag: 'session_failed',
  })
})
