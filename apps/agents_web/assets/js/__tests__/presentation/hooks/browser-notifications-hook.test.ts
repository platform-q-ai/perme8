import { afterEach, beforeEach, describe, expect, test, vi } from 'vitest'

import { BrowserNotificationsHook } from '../../../presentation/hooks/browser-notifications-hook'

describe('BrowserNotificationsHook', () => {
  let hook: BrowserNotificationsHook
  let el: HTMLElement
  let handlers: Record<string, (payload: unknown) => void>
  let notificationSpy: ReturnType<typeof vi.fn>

  beforeEach(() => {
    document.body.innerHTML = ''
    handlers = {}
    el = document.createElement('div')
    ;(el as any).phxPrivate = {}

    hook = new BrowserNotificationsHook(null as any, el)
    ;(hook as any).handleEvent = (name: string, callback: (payload: unknown) => void) => {
      handlers[name] = callback
    }

    notificationSpy = vi.fn()
    Object.defineProperty(globalThis, 'Notification', {
      configurable: true,
      writable: true,
      value: Object.assign(notificationSpy, {
        permission: 'default',
        requestPermission: vi.fn().mockResolvedValue('granted')
      })
    })
  })

  afterEach(() => {
    vi.restoreAllMocks()
    document.body.innerHTML = ''
    window.localStorage.clear()
  })

  test('renders a permission prompt when notifications are undecided', () => {
    hook.mounted()

    const prompt = document.getElementById('browser-notifications-permission-prompt')
    expect(prompt).not.toBeNull()
    expect(prompt?.textContent).toContain('Enable browser notifications')
  })

  test('does not render a permission prompt when notifications were dismissed', () => {
    window.localStorage.setItem('browser-notifications-dismissed', 'true')

    hook.mounted()

    expect(document.getElementById('browser-notifications-permission-prompt')).toBeNull()
  })

  test('shows a browser notification for background session completion', () => {
    Object.assign(Notification, { permission: 'granted' })
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'hidden'
    })

    hook.mounted()
    handlers.browser_notification?.({
      title: 'Session completed',
      body: 'Implemented the feature',
      type: 'session_completed'
    })

    expect(notificationSpy).toHaveBeenCalledWith('Session completed', {
      body: 'Implemented the feature',
      tag: 'session_completed'
    })
  })

  test('does not show a browser notification while the page is visible', () => {
    Object.assign(Notification, { permission: 'granted' })
    Object.defineProperty(document, 'visibilityState', {
      configurable: true,
      value: 'visible'
    })

    hook.mounted()
    handlers.browser_notification?.({
      title: 'Session completed',
      body: 'Implemented the feature',
      type: 'session_completed'
    })

    expect(notificationSpy).not.toHaveBeenCalled()
  })
})
