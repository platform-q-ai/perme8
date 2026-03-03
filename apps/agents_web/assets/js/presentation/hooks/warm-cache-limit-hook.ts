import { ViewHook } from 'phoenix_live_view'

const keyFor = (userId: string): string => `agents:warm_cache_limit:${userId}`

export class WarmCacheLimitHook extends ViewHook<HTMLSelectElement> {
  private onChange?: (event: Event) => void

  mounted(): void {
    const userId = this.el.dataset.userId ?? 'anon'
    const key = keyFor(userId)
    const persisted = window.localStorage.getItem(key)

    if (persisted && persisted !== this.el.value) {
      this.el.value = persisted
      const form = this.el.closest('form')
      if (form) {
        form.dispatchEvent(new Event('change', { bubbles: true }))
      }
    }

    this.onChange = () => {
      window.localStorage.setItem(key, this.el.value)
    }

    this.el.addEventListener('change', this.onChange)
  }

  destroyed(): void {
    if (this.onChange) {
      this.el.removeEventListener('change', this.onChange)
    }
  }
}
