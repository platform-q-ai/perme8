import { ViewHook } from 'phoenix_live_view'

const DISMISSED_KEY = 'browser-notifications-dismissed'

type BrowserNotificationPayload = {
  title?: string
  body?: string | null
  type?: string
}

export class BrowserNotificationsHook extends ViewHook {
  private promptEl: HTMLElement | null = null

  mounted(): void {
    this.maybeRenderPrompt()

    this.handleEvent('browser_notification', (payload: BrowserNotificationPayload) => {
      this.showBrowserNotification(payload)
    })
  }

  destroyed(): void {
    this.removePrompt()
  }

  private maybeRenderPrompt(): void {
    if (!this.supportsBrowserNotifications()) return
    if (Notification.permission !== 'default') return
    if (window.localStorage.getItem(DISMISSED_KEY) === 'true') return
    if (this.promptEl) return

    const prompt = document.createElement('div')
    prompt.id = 'browser-notifications-permission-prompt'
    prompt.className =
      'fixed bottom-4 right-4 z-50 rounded-lg border border-base-300 bg-base-100 p-4 shadow-lg max-w-sm'

    const text = document.createElement('p')
    text.className = 'text-sm'
    text.textContent = 'Enable browser notifications to get task updates when this tab is in the background.'

    const actions = document.createElement('div')
    actions.className = 'mt-3 flex gap-2'

    const enable = document.createElement('button')
    enable.type = 'button'
    enable.className = 'btn btn-primary btn-sm'
    enable.textContent = 'Enable'
    enable.addEventListener('click', () => {
      Notification.requestPermission().then((permission) => {
        if (permission !== 'default') {
          this.removePrompt()
        }
      })
    })

    const dismiss = document.createElement('button')
    dismiss.type = 'button'
    dismiss.className = 'btn btn-ghost btn-sm'
    dismiss.textContent = 'Not now'
    dismiss.addEventListener('click', () => {
      window.localStorage.setItem(DISMISSED_KEY, 'true')
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

    const title = payload.title || 'New notification'
    const body = payload.body || ''

    const notification = new Notification(title, {
      body,
      tag: payload.type || 'notification'
    })

    notification.onclick = () => {
      window.focus()
      notification.close()
    }
  }

  private supportsBrowserNotifications(): boolean {
    return typeof window !== 'undefined' && 'Notification' in window
  }

  private removePrompt(): void {
    if (!this.promptEl) return
    this.promptEl.remove()
    this.promptEl = null
  }
}
