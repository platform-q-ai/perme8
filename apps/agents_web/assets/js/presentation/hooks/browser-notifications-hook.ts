import { ViewHook } from 'phoenix_live_view'

const DISMISSED_KEY = 'browser-notifications-dismissed'

type BrowserNotificationPayload = {
  title?: string
  body?: string | null
  type?: string
}

/**
 * Mounts on the sessions page to request browser notification permission and
 * display `browser_notification` events sent by the LiveView while the page is backgrounded.
 */
export class BrowserNotificationsHook extends ViewHook {
  private promptEl: HTMLElement | null = null

  mounted(): void {
    ;(window as Window & { __agentsBrowserNotificationsHook?: BrowserNotificationsHook }).__agentsBrowserNotificationsHook = this
    this.maybeRenderPrompt()

    this.handleEvent('browser_notification', (payload: BrowserNotificationPayload) => {
      this.showBrowserNotification(payload)
    })
  }

  destroyed(): void {
    delete (window as Window & { __agentsBrowserNotificationsHook?: BrowserNotificationsHook }).__agentsBrowserNotificationsHook
    this.removePrompt()
  }

  private maybeRenderPrompt(): void {
    if (!this.supportsBrowserNotifications()) return
    if (Notification.permission !== 'default') return
    if (this.isDismissed()) return
    if (this.promptEl) return

    const prompt = document.createElement('div')
    prompt.id = 'browser-notifications-permission-prompt'
    prompt.className =
      'fixed bottom-4 right-4 z-50 max-w-sm rounded-lg border border-base-300 bg-base-100 p-4 shadow-lg'

    const text = document.createElement('p')
    text.className = 'text-sm'
    text.textContent =
      'Enable browser notifications to get session updates when this tab is in the background.'

    const actions = document.createElement('div')
    actions.className = 'mt-3 flex gap-2'

    const enable = document.createElement('button')
    enable.type = 'button'
    enable.className = 'btn btn-primary btn-sm'
    enable.textContent = 'Enable'
    enable.addEventListener('click', () => {
      void Notification.requestPermission()
        .then((permission) => {
          if (permission !== 'default') {
            this.removePrompt()
          }
        })
        .catch(() => undefined)
    })

    const dismiss = document.createElement('button')
    dismiss.type = 'button'
    dismiss.className = 'btn btn-ghost btn-sm'
    dismiss.textContent = 'Not now'
    dismiss.addEventListener('click', () => {
      this.setDismissed()
      this.removePrompt()
    })

    actions.appendChild(enable)
    actions.appendChild(dismiss)
    prompt.appendChild(text)
    prompt.appendChild(actions)

    document.body.appendChild(prompt)
    this.promptEl = prompt
  }

  private showBrowserNotification(payload: BrowserNotificationPayload): void {
    if (!this.supportsBrowserNotifications()) return
    if (Notification.permission !== 'granted') return
    if (document.visibilityState === 'visible') return

    const title = payload.title || 'Session update'
    const body = payload.body || ''

    const notification = new Notification(title, {
      body,
      tag: payload.type || 'session_update'
    })

    notification.onclick = () => {
      window.focus()
      notification.close()
    }
  }

  private supportsBrowserNotifications(): boolean {
    return typeof window !== 'undefined' && 'Notification' in window
  }

  private isDismissed(): boolean {
    try {
      return window.localStorage.getItem(DISMISSED_KEY) === 'true'
    } catch {
      return false
    }
  }

  private setDismissed(): void {
    try {
      window.localStorage.setItem(DISMISSED_KEY, 'true')
    } catch {
      return
    }
  }

  private removePrompt(): void {
    if (!this.promptEl) return

    this.promptEl.remove()
    this.promptEl = null
  }
}
